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
    
    /// Installs and connects helper
    static let helperService = HelperService()
    
    /// Discovers providers
    static let providerService = ProviderService(urlSession: urlSession, authenticationService: authenticationService)
    
    /// Authenticates user with provider
    static let authenticationService = AuthenticationService()
   
    /// Fetches configuration
    static let configurationService = ConfigurationService(urlSession: urlSession, authenticationService: authenticationService)
    
    /// Connects to VPN
    static let connectionService = ConnectionService(configurationService: configurationService, helperService: helperService)
    
    /// Handles preferences
    static let preferencesService = PreferencesService()
    
}
