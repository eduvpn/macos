//
//  ConnectionService.swift
//  EduVPN
//
//  Created by Johan Kool on 30/06/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

import Foundation
import AppKit
import ServiceManagement
import AppAuth

typealias Config = String

/// Connects to VPN
class ConnectionService: NSObject {
    
    static let openVPNSubdirectory = "openvpn-2.4.3-openssl-1.0.2k"
    
    enum Error: LocalizedError {
        case noHelperConnection
        
        var localizedDescription: String {
            switch self {
            case .noHelperConnection:
                return NSLocalizedString("Installation failed", comment: "")
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .noHelperConnection:
                return NSLocalizedString("Try reinstalling EduVPN.", comment: "")
            }
        }
    }
 
    private let configurationService: ConfigurationService
    private let helperService: HelperService
    
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
    func connect(to profile: Profile, authState: OIDAuthState, handler: @escaping (Either<Void>) -> ()) {
        helperService.installHelperIfNeeded { (result) in
            switch result {
            case .success:
                self.configurationService.configure(for: profile, authState: authState) { (result) in
                    switch result {
                    case .success(let config):
                        do {
                            let configURL = try self.install(config: config) // TODO: uninstall config
                            self.activateConfig(at: configURL, handler: handler)
                        } catch(let error) {
                            handler(.failure(error))
                        }
                    case .failure(let error):
                        handler(.failure(error))
                    }
                }
            case .failure(let error):
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
        let tempDir = NSTemporaryDirectory()
        let fileURL = URL(fileURLWithPath: tempDir + "/eduvpn.ovpn")
        try config.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    /// Asks helper service to start VPN connection
    ///
    /// - Parameters:
    ///   - configURL: URL of config file
    ///   - handler: Succes or error
    private func activateConfig(at configURL: URL, handler: @escaping (Either<Void>) -> ()) {
        guard let helper = helperService.connection?.remoteObjectProxy as? OpenVPNHelperProtocol else {
            handler(.failure(Error.noHelperConnection))
            return
        }
        
        let bundle = Bundle.init(for: ConnectionService.self)
        let openvpnURL = bundle.url(forResource: "openvpn", withExtension: nil, subdirectory: ConnectionService.openVPNSubdirectory)!
        
        helper.startOpenVPN(at: openvpnURL, withConfig: configURL) { (message) in
            handler(.success())
        }
    }
    
    /// Asks helper to disconnect VPN connection
    ///
    /// - Parameter handler: <#handler description#>
    func disconnect(_ handler: @escaping (Either<Void>) -> ()) {
        guard let helper = helperService.connection?.remoteObjectProxy as? OpenVPNHelperProtocol else {
            handler(.failure(Error.noHelperConnection))
            return
        }
        
        helper.close { (message) in
            handler(.success())
        }
    }
    
}

//extension ConnectionService: ClientProtocol {
//    
//    func stateChanged(_ state: OpenVPNState, reply: (() -> Void)) {
//        NSLog("state \(state)")
//    }
//}
