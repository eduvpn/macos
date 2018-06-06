//
//  ServiceContainer.swift
//  eduVPN
//
//  Created by Johan Kool on 30/06/2017.
//  Copyright © 2017 eduVPN. All rights reserved.
//

import Foundation

/// Entrypoint to services
struct ServiceContainer {
    
    /// URL session to perform network requests
    static let urlSession: URLSession = {
        let urlSession =  URLSession(configuration: .ephemeral)
        return urlSession
    }()
    
    static var appName: String {
        switch Bundle.main.bundleIdentifier! {
        case "org.eduvpn.app":
            return "eduVPN"
        case "org.eduvpn.app.home":
            return "Let's connect!"
        default:
            fatalError()
        }
    }
    
    /// Installs and connects helper
    static let helperService = HelperService()
    
    /// Discovers providers
    static let providerService = ProviderService(urlSession: urlSession, authenticationService: authenticationService, appName: appName)
    
    /// Registers 2FA
    static let twoFactorService = TwoFactorService(urlSession: urlSession, authenticationService: authenticationService)
    
    /// Authenticates user with provider
    static let authenticationService = AuthenticationService(appName: appName)
   
    /// Fetches configuration
    static let configurationService = ConfigurationService(urlSession: urlSession, authenticationService: authenticationService, keychainService: keychainService)
    
    /// Connects to VPN
    static let connectionService = ConnectionService(configurationService: configurationService, helperService: helperService, keychainService: keychainService)
    
    /// Handles preferences
    static let preferencesService = PreferencesService()
    
    /// Imports, retrieves certificates, signs data
    static let keychainService = KeychainService()
}
