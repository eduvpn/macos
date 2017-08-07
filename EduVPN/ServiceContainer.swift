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
    
    /// Installs and connects helper
    static let helperService = HelperService()
    
    /// Discovers providers
    static let providerService = ProviderService()
    
    /// Authenticates user with provider
    static let authenticationService = AuthenticationService()
   
    /// Fetches configuration
    static let configurationService = ConfigurationService()
    
    /// Connects to VPN
    static let connectionService = ConnectionService(configurationService: configurationService, helperService: helperService)
    
}
