//
//  HelperService.swift
//  EduVPN
//
//  Created by Johan Kool on 06/07/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

import Foundation
import AppKit
import Security
import ServiceManagement

/// Installs and connects helper
class HelperService {
    
    static let helperVersion = "1.0-1"
    static let helperIdentifier = "org.eduvpn.app.openvpnhelper"

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
    
    private var connection: NSXPCConnection?
    private var authRef: AuthorizationRef?
    // private var authorization: Data!

    init() {
        installHelperIfNeeded()
    }
    
    private func installHelperIfNeeded() {
        connectToHelper { upToDate in
            if upToDate {
                // Connected and up-to-date
            } else {
                // Not installed or not up-to-date
                do {
                    try self.installHelper()
                } catch (let error) {
                    // Installation failed
                    let alert = NSAlert(error: error)
                    alert.runModal()
                }
                // Installation succeeded, try again
                self.connectToHelper { upToDate in
                    if upToDate {
                        // Connected and up-to-date
                    } else {
                        // Something went haywhire
                        let alert = NSAlert(error: Error.installationFailed)
                        alert.runModal()
                    }
                }
            }
        }
    }
    
    private func installHelper() throws {
        var status = AuthorizationCreate(nil, nil, AuthorizationFlags(), &authRef)
        if (status != OSStatus(errAuthorizationSuccess)) {
            print("AuthorizationCreate failed.")
            throw Error.authenticationFailed
        }
        
        var item = AuthorizationItem(name: kSMRightBlessPrivilegedHelper, valueLength: 0, value: nil, flags: 0)
        var rights = AuthorizationRights(count: 1, items: &item)
        let flags = AuthorizationFlags([.interactionAllowed, .extendRights])
        
        status = AuthorizationCopyRights(authRef!, &rights, nil, flags, nil)
        if (status != errAuthorizationSuccess) {
            print("AuthorizationCopyRights failed.")
            throw Error.authenticationFailed
        }
        
        var error: Unmanaged<CFError>?
        let success = SMJobBless(
            kSMDomainSystemLaunchd,
            HelperService.helperIdentifier as CFString,
            authRef,
            &error
        );
        
        if (success) {
            NSLog("job blessed")
        } else {
            NSLog("job NOT blessed \(String(describing: error))")
            throw Error.installationFailed
        }
    }
    
    private func connectToHelper(_ callback: @escaping (Bool) -> ()) {
        connection = NSXPCConnection(machServiceName: HelperService.helperIdentifier, options: .privileged)
        connection?.remoteObjectInterface = NSXPCInterface(with: OpenVPNHelperProtocol.self)
        connection?.exportedInterface = NSXPCInterface(with: ClientProtocol.self)
        connection?.exportedObject = self
        connection?.invalidationHandler = { _ in
            NSLog("connection invalidated!")
        }
        connection?.interruptionHandler = { _ in
            NSLog("connection interrupted!")
        }
        connection?.resume()
        
        do {
            try getHelperVersion { (version) in
                callback(version == HelperService.helperVersion)
            }
        } catch {
            callback(false)
        }
    }
    
//    var openVPNHelper: OpenVPNHelperProtocol? {
//        guard let helper = connection?.remoteObjectProxyWithErrorHandler({ error in
//            NSLog("connection error: \(error)")
//          //  callback("")
//        }) as? OpenVPNHelperProtocol else {
//            throw Error.noHelperConnection
//        }
//        
//        return helper
//    }
    
    private func getHelperVersion(_ callback: @escaping (String) -> ()) throws {
        guard let helper = connection?.remoteObjectProxyWithErrorHandler({ error in
            NSLog("connection error: \(error)")
            callback("")
        }) as? OpenVPNHelperProtocol else {
            throw Error.noHelperConnection
        }
        
        helper.getVersionWithReply() { (version) in
            callback(version ?? "")
        }
    }
    

}
