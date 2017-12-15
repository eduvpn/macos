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
        case connected
        case disconnecting
        case disconnected
    }
    
    enum Error: Swift.Error, LocalizedError {
        case noHelperConnection
        case helperRejected
        case statisticsUnavailable
        case unexpectedState
        
        var errorDescription: String? {
            switch self {
            case .noHelperConnection:
                return NSLocalizedString("Installation failed", comment: "")
            case .helperRejected:
                return NSLocalizedString("Helper rejected request", comment: "")
            case .statisticsUnavailable:
                return NSLocalizedString("No connection statistics available", comment: "")
            case .unexpectedState:
                return NSLocalizedString("Connection in unexpected state", comment: "")
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
            case .unexpectedState:
                return NSLocalizedString("Try again.", comment: "")
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
    ///   - twoFactor: Optional two factor authentication token
    ///   - authState: Authentication token
    ///   - handler: Success or error
    func connect(to profile: Profile, twoFactor: TwoFactor?, authState: OIDAuthState, handler: @escaping (Result<Void>) -> ()) {
        guard state == .disconnected else {
            handler(.failure(Error.unexpectedState))
            return
        }
        state = .connecting
        
        helperService.installHelperIfNeeded(client: self) { (result) in
            switch result {
            case .success:
                self.configurationService.configure(for: profile, authState: authState) { (result) in
                    switch result {
                    case .success(let config):
                        do {
                            let configURL = try self.install(config: config)
                            let authUserPassURL: URL?
                            if let twoFactor = twoFactor {
                                authUserPassURL = try self.install(twoFactor: twoFactor)
                            } else {
                                authUserPassURL = nil
                            }
                            self.activateConfig(at: configURL, authUserPassURL: authUserPassURL, handler: handler)
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
    
    /// Installs authUserPass
    ///
    /// - Parameter twoFactor: Two Factor Authenticationtoken
    /// - Returns: URL where authUserPass was installed
    /// - Throws: Error writing config to disk
    private func install(twoFactor: TwoFactor) throws -> URL {
        let username: String
        let password: String
        switch twoFactor {
        case .totp(let token):
            username = "totp"
            password = token
        case .yubico(let token):
            username = "yubi"
            password = token
        }
        
        let tempDir = (NSTemporaryDirectory() as NSString).appendingPathComponent("org.eduvpn.app.temp") // Added .temp because .app lets the Finder show the folder as an app
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true, attributes: nil)
        let fileURL = URL(fileURLWithPath: (tempDir as NSString).appendingPathComponent("eduvpn.aup"))
        try "\(username)\n\(password)".write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    /// Asks helper service to start VPN connection
    ///
    /// - Parameters:
    ///   - configURL: URL of config file
    ///   - handler: Succes or error
    private func activateConfig(at configURL: URL, authUserPassURL: URL?, handler: @escaping (Result<Void>) -> ()) {
        guard state == .connecting else {
            handler(.failure(Error.unexpectedState))
            return
        }
        
        guard let helper = helperService.connection?.remoteObjectProxy as? OpenVPNHelperProtocol else {
            handler(.failure(Error.noHelperConnection))
            return
        }
        
        let bundle = Bundle.init(for: ConnectionService.self)
        let openvpnURL = bundle.url(forResource: "openvpn", withExtension: nil, subdirectory: ConnectionService.openVPNSubdirectory)!
        self.configURL = configURL
        self.authUserPassURL = authUserPassURL
        helper.startOpenVPN(at: openvpnURL, withConfig: configURL, authUserPass: authUserPassURL) { (success) in
            if success {
                self.state = .connected
                handler(.success(Void()))
            } else {
                self.state = .disconnected
                self.configURL = nil
                self.authUserPassURL = nil
                handler(.failure(Error.helperRejected))
            }
        }
    }
    
    /// Uninstalls file
    ///
    /// - Parameter fileURL: URL where file was installed
    /// - Throws: Error removing file from disk
    private func uninstall(fileURL: URL) {
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch(let error) {
            print("Failed to remove file at URL %@ with error: %@", fileURL, error)
        }
    }
    
    /// Asks helper to disconnect VPN connection
    ///
    /// - Parameter handler: Success or error
    func disconnect(_ handler: @escaping (Result<Void>) -> ()) {
        guard state == .connected else {
            handler(.failure(Error.unexpectedState))
            return
        }
        
        state = .disconnecting
        
        guard let helper = helperService.connection?.remoteObjectProxy as? OpenVPNHelperProtocol else {
            self.state = .connected
            handler(.failure(Error.noHelperConnection))
            return
        }
        
        helper.close { 
            self.state = .disconnected
            self.configURL = nil
            self.authUserPassURL = nil
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
    
    /// URL to the last loaded config (which may have been deleted already!)
    private(set) var configURL: URL? {
        didSet(oldValue) {
            if let oldURL = oldValue {
                uninstall(fileURL: oldURL)
            }
        }
    }
    
    /// URL to the last loaded auth-user-pass (which may have been deleted already!)
    private(set) var authUserPassURL: URL? {
        didSet(oldValue) {
            if let oldURL = oldValue {
                uninstall(fileURL: oldURL)
            }
        }
    }
    
    /// URL to the log file
    var logURL: URL? {
        return configURL?.appendingPathExtension("log")
    }
}

extension ConnectionService: ClientProtocol {
    
    func taskTerminated(reply: @escaping () -> Void) {
        self.state = .disconnecting
        reply()
        self.state = .disconnected
    }

}
