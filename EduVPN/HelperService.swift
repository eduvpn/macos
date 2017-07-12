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

    enum Error: Int, LocalizedError {
        case noHelperConnection
        case authenticationFailed
        case installationFailed

        var localizedDescription: String {
            switch self {
            case .noHelperConnection:
                return NSLocalizedString("Installation failed", comment: "")
            case .authenticationFailed:
                return NSLocalizedString("Authentication failed", comment: "")
            case .installationFailed:
                return NSLocalizedString("Installation failed", comment: "")
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .noHelperConnection:
                return NSLocalizedString("Try reinstalling EduVPN.", comment: "")
            case .authenticationFailed:
                return NSLocalizedString("Try to connect again.", comment: "")
            case .installationFailed:
                return NSLocalizedString("Try reinstalling EduVPN.", comment: "")
            }
        }
    }
    
    private(set) var connection: NSXPCConnection?
    private var authRef: AuthorizationRef?
    
    // For reference: pass to helper?
    // private var authorization: Data!
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
    
    /// Installs the helper if needed
    ///
    /// - Parameter handler: Succes or error
    func installHelperIfNeeded(_ handler: @escaping (Either<Void>) -> ()) {
        connectToHelper { result in
            switch result {
            case .success(let upToDate):
                if upToDate {
                    handler(.success())
                    return
                }
            case .failure:
                break
            }
            
            self.installHelper { result in
                switch result {
                case .success:
                    self.connectToHelper { result in
                        switch result {
                        case .success(let upToDate):
                            if upToDate {
                                handler(.success())
                            } else {
                                handler(.failure(Error.installationFailed))
                            }
                        case .failure:
                            handler(.failure(Error.installationFailed))
                        }
                    }
                case .failure:
                    handler(.failure(Error.installationFailed))
                }
            }
        }
    }
    
    /// Installs the helper
    ///
    /// - Parameter handler: Succes or error
    private func installHelper(_ handler: @escaping (Either<Void>) -> ()) {
        var status = AuthorizationCreate(nil, nil, AuthorizationFlags(), &authRef)
        guard status == errAuthorizationSuccess else {
            handler(.failure(Error.authenticationFailed))
            return
        }
        
        var item = AuthorizationItem(name: kSMRightBlessPrivilegedHelper, valueLength: 0, value: nil, flags: 0)
        var rights = AuthorizationRights(count: 1, items: &item)
        let flags = AuthorizationFlags([.interactionAllowed, .extendRights])
        
        status = AuthorizationCopyRights(authRef!, &rights, nil, flags, nil)
        guard status == errAuthorizationSuccess else {
            handler(.failure(Error.authenticationFailed))
            return
        }
        
        var error: Unmanaged<CFError>?
        let success = SMJobBless(
            kSMDomainSystemLaunchd,
            HelperService.helperIdentifier as CFString,
            authRef,
            &error
        )
        
        if success {
            handler(.success())
        } else {
            handler(.failure(Error.installationFailed))
        }
    }
    
    /// Sets up a connection with the helper
    ///
    /// - Parameter handler: True if up-to-date, false is older version or eror
    private func connectToHelper(_ handler: @escaping (Either<Bool>) -> ()) {
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
        
        getHelperVersion { (result) in
            switch result {
            case .success(let version):
                handler(.success(version == HelperService.helperVersion))
            case .failure(let error):
                handler(.failure(error))
            }
        }
    }
    
    /// Ask the helper for its version
    ///
    /// - Parameter handler: Version or error
    private func getHelperVersion(_ handler: @escaping (Either<String>) -> ()) {
        guard let helper = connection?.remoteObjectProxyWithErrorHandler({ error in
            handler(.failure(error))
        }) as? OpenVPNHelperProtocol else {
            handler(.failure(Error.noHelperConnection))
            return
        }
        
        helper.getVersionWithReply() { (version) in
            handler(.success(version))
        }
    }

}
