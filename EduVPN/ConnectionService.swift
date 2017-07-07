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
    
    static let ConnectionEstablished: NSNotification.Name = NSNotification.Name("ConnectionService.ConnectionEstablished")
    static let ConnectionTerminated: NSNotification.Name = NSNotification.Name("ConnectionService.ConnectionTerminated")

    enum Error: Int, Swift.Error, LocalizedError {
        case invalidProviderInfo
        case invalidURL
        case unexpectedState
        case invalidKeyPair
        case invalidConfiguration
        case noHelperConnection
        case authenticationFailed
        case installationFailed
        case unknown
        
        //    var errorDescription: String? {
        //        switch self {
        //        case .installationFailed:
        //            return NSLocalizedString("Installation failed", comment: "")
        //        default:
        //            return NSLocalizedString("Connection error \(self)", comment: "")
        //        }
        //    }
        
        var failureReason: String? {
            switch self {
            case .installationFailed:
                return NSLocalizedString("Installation failed", comment: "")
            default:
                return nil
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .installationFailed:
                return NSLocalizedString("Try reinstalling EduVPN.", comment: "")
            default:
                return nil
            }
        }
    }

 
    let configurationService: ConfigurationService
    let helperService: HelperService
    
    init(configurationService: ConfigurationService, helperService: HelperService) {
        self.configurationService = configurationService
        self.helperService = helperService
    }

    func connect(to profile: Profile, authState: OIDAuthState, handler: @escaping (Either<Void>) -> ()) {
        configurationService.configure(for: profile, authState: authState) { (result) in
            switch result {
            case .success(let config):
                do {
                    let configURL = try self.install(config: config)
                    self.activateConfig(at: configURL, handler: handler)
                } catch(let error) {
                    handler(.failure(error))
                }
            case .failure(let error):
                handler(.failure(error))
            }
        }
    }
    
    private func install(config: String) throws -> URL {
        let tempDir = NSTemporaryDirectory()
        let fileURL = URL(fileURLWithPath: tempDir + "/eduvpn.ovpn")
        try config.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    
    
//    private func connectToAuthorization() {
//        var authRef: AuthorizationRef?
//        var err = AuthorizationCreate(nil, nil, [], &authRef)
//        self.authRef = authRef
//       
//        var form = AuthorizationExternalForm()
//        
//        if (err == errAuthorizationSuccess) {
//            err = AuthorizationMakeExternalForm(authRef!, &form);
//        }
//        if (err == errAuthorizationSuccess) {
//            self.authorization = Data(bytes: &form.bytes, count: MemoryLayout.size(ofValue: form.bytes))
//        }
//    }
    
    var connection: NSXPCConnection?
    
    private func activateConfig(at configURL: URL, handler: @escaping (Either<Void>) -> ()) {
        
        if let helper = connection?.remoteObjectProxyWithErrorHandler({ (error) in
            NSLog("connection error: \(error)")
            handler(.failure(Error.noHelperConnection))
        }) as? OpenVPNHelperProtocol {

            
            let bundle = Bundle.init(for: ConnectionService.self)
            
            let openvpnURL = bundle.url(forResource: "openvpn", withExtension: nil, subdirectory: ConnectionService.openVPNSubdirectory)!
            
            helper.startOpenVPN(at: openvpnURL, withConfig: configURL) { (message) in
                handler(.success())
                NSLog("did connect?: \(message)")
                NotificationCenter.default.post(name: ConnectionService.ConnectionEstablished, object: self)
            }
        }
        
    }
    
    func disconnect(handler: @escaping (Either<Void>) -> ()) {
        guard let helper = connection?.remoteObjectProxy as? OpenVPNHelperProtocol else {
            handler(.failure(Error.noHelperConnection))
            return
        }
        
        helper.close { (message) in
            handler(.success())
            NSLog("did disconnect?: \(message)")
            NotificationCenter.default.post(name: ConnectionService.ConnectionTerminated, object: self)
        }
    }
    
}

extension ConnectionService: ClientProtocol {
    
    func stateChanged(_ state: OpenVPNState, reply: (() -> Void)!) {
        NSLog("state \(state)")
    }
}
