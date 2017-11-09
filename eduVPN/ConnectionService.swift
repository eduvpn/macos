//
//  ConnectionService.swift
//  eduVPN
//
//  Created by Johan Kool on 30/06/2017.
//  Copyright © 2017 eduVPN. All rights reserved.
//

import Foundation
import AppKit
import ServiceManagement
import AppAuth

typealias Config = String

/// Connects to VPN
class ConnectionService: NSObject {
    
    static let openVPNSubdirectory = "openvpn-2.4.4-openssl-1.0.2k"
    
    /// Notification posted when connection state changes
    static let stateChanged = NSNotification.Name("ConnectionService.stateChanged")
    
    /// Connection state
    ///
    /// - connecting: Service is attempting to connect
    /// - connected: Service is connected
    /// - disconnecting: Service is attempting to disconnect
    /// - disconnected: Service is disconnected
    enum State: Equatable {
        case connecting
        case connected(configURL: URL)
        case disconnecting
        case disconnected
        
        static func ==(lhs: ConnectionService.State, rhs: ConnectionService.State) -> Bool {
            switch (lhs, rhs) {
            case (.connecting, .connecting):
                return true
            case (.connected(let lhsConfigUrl), .connected(let rhsConfigUrl)):
                return lhsConfigUrl == rhsConfigUrl
            case (.disconnecting, .disconnecting):
                return true
            case (.disconnected, .disconnected):
                return true
            default:
                return false
            }
        }
        
        /// Convenience property needed to handle associated value
        var isConnected: Bool {
            if case .connected = self {
                return true
            } else {
                return false
            }
        }
    }
    
    enum Error: Swift.Error, LocalizedError {
        case noHelperConnection
        case helperRejected
        case statisticsUnavailable
        
        var errorDescription: String? {
            switch self {
            case .noHelperConnection:
                return NSLocalizedString("Installation failed", comment: "")
            case .helperRejected:
                return NSLocalizedString("Helper rejected request", comment: "")
            case .statisticsUnavailable:
                return NSLocalizedString("No connection statistics available", comment: "")
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .noHelperConnection:
                return NSLocalizedString("Try reinstalling eduVPN.", comment: "")
            case .helperRejected:
                return NSLocalizedString("Try reinstalling eduVPN.", comment: "")
            case .statisticsUnavailable:
                return NSLocalizedString("Try again later.", comment: "")
            }
        }
    }
 
    private let configurationService: ConfigurationService
    private let helperService: HelperService
    
    /// Describes current connection state
    private(set) var state: State = .disconnected {
        didSet {
            if oldValue != state {
                NotificationCenter.default.post(name: ConnectionService.stateChanged, object: self)
            }
        }
    }
    
    init(configurationService: ConfigurationService, helperService: HelperService) {
        self.configurationService = configurationService
        self.helperService = helperService
    }

    /// Asks helper service to start VPN connection after helper and config are ready and available
    ///
    /// - Parameters:
    ///   - profile: Profile
    ///   - authState: Authentication token
    ///   - handler: Success or error
    func connect(to profile: Profile, authState: OIDAuthState, handler: @escaping (Result<Void>) -> ()) {
        assert(state == .disconnected)
        state = .connecting
        
        helperService.installHelperIfNeeded(client: self) { (result) in
            switch result {
            case .success:
                self.configurationService.configure(for: profile, authState: authState) { (result) in
                    switch result {
                    case .success(let config):
                        do {
                            let configURL = try self.install(config: config)
                            self.activateConfig(at: configURL, handler: handler)
                        } catch(let error) {
                            self.state = .disconnected
                            handler(.failure(error))
                        }
                    case .failure(let error):
                        self.state = .disconnected
                        handler(.failure(error))
                    }
                }
            case .failure(let error):
                self.state = .disconnected
                handler(.failure(error))
            }
        }
    }

    /// Installs configuration
    ///
    /// - Parameter config: Config
    /// - Returns: URL where config was installed
    /// - Throws: Error writing config to disk
    private func install(config: String) throws -> URL {
        let tempDir = (NSTemporaryDirectory() as NSString).appendingPathComponent("org.eduvpn.app.temp") // Added .temp because .app lets the Finder show the folder as an app
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true, attributes: nil)
        let fileURL = URL(fileURLWithPath: (tempDir as NSString).appendingPathComponent("eduvpn.ovpn"))
        try config.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    /// Asks helper service to start VPN connection
    ///
    /// - Parameters:
    ///   - configURL: URL of config file
    ///   - handler: Succes or error
    private func activateConfig(at configURL: URL, handler: @escaping (Result<Void>) -> ()) {
        assert(state == .connecting)
        
        guard let helper = helperService.connection?.remoteObjectProxy as? OpenVPNHelperProtocol else {
            handler(.failure(Error.noHelperConnection))
            return
        }
        
        let bundle = Bundle.init(for: ConnectionService.self)
        let openvpnURL = bundle.url(forResource: "openvpn", withExtension: nil, subdirectory: ConnectionService.openVPNSubdirectory)!
        
        helper.startOpenVPN(at: openvpnURL, withConfig: configURL) { (success) in
            if success {
                self.state = .connected(configURL: configURL)
                handler(.success(Void()))
            } else {
                self.state = .disconnected
                handler(.failure(Error.helperRejected))
            }
            // Remove config file
            do {
                try self.uninstall(configURL: configURL)
            } catch(let error) {
                print("Failed to remove config at URL %@ with error: %@", configURL, error)
            }
        }
    }
    
    /// Uninstalls configuration
    ///
    /// - Parameter configURL: URL where config was installed
    /// - Throws: Error removing config from disk
    private func uninstall(configURL: URL) throws {
        try FileManager.default.removeItem(at: configURL)
    }
    
    /// Asks helper to disconnect VPN connection
    ///
    /// - Parameter handler: Success or error
    func disconnect(_ handler: @escaping (Result<Void>) -> ()) {
        let oldState = state
        assert(state.isConnected)
        state = .disconnecting
        
        guard let helper = helperService.connection?.remoteObjectProxy as? OpenVPNHelperProtocol else {
            self.state = oldState
            handler(.failure(Error.noHelperConnection))
            return
        }
        
        helper.close { 
            self.state = .disconnected
            handler(.success(Void()))
        }
    }
    
    /// Asks helper for statistics about current VPN connection
    ///
    /// - Parameter handler: Statistics or error
    func readStatistics(_ handler: @escaping (Result<Statistics>) -> ()) {
        guard let helper = helperService.connection?.remoteObjectProxy as? OpenVPNHelperProtocol else {
            handler(.failure(Error.noHelperConnection))
            return
        }
        
        helper.readStatistics { (statistics) in
            if let statistics = statistics {
                handler(.success(statistics))
            } else {
                handler(.failure(Error.statisticsUnavailable))
            }
        }
    }
}

extension ConnectionService: ClientProtocol {
    
    func taskTerminated(reply: @escaping () -> Void) {
        reply()
    }

}
