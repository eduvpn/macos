//
//  AuthenticationService.swift
//  EduVPN
//
//  Created by Johan Kool on 06/07/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

import Foundation
import AppKit
import AppAuth

/// Authorizes user with provider
class AuthenticationService {
    
    enum Error: Swift.Error {
        case unknown
    }
    
    private var redirectHTTPHandler: OIDRedirectHTTPHandler?
    
    /// Start authentication process with provider
    ///
    /// - Parameters:
    ///   - info: Provider info
    ///   - handler: Auth state or error
    func authenticate(using info: ProviderInfo, handler: @escaping (Either<OIDAuthState>) -> ()) {
        let configuration = OIDServiceConfiguration(authorizationEndpoint: info.authorizationURL, tokenEndpoint: info.tokenURL)
        
        redirectHTTPHandler = OIDRedirectHTTPHandler(successURL: nil)
        let redirectURL = URL(string: "callback", relativeTo: redirectHTTPHandler!.startHTTPListener(nil))!
        let request = OIDAuthorizationRequest(configuration: configuration, clientId: "org.eduvpn.app", clientSecret: nil, scopes: ["config"], redirectURL: redirectURL, responseType: OIDResponseTypeCode, additionalParameters: nil)
        
        redirectHTTPHandler!.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request) { (authState, error) in
            NSRunningApplication.current().activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            
            if let authState = authState {
                handler(.success(authState))
            } else if let error = error {
                handler(.failure(error))
            } else {
                handler(.failure(Error.unknown))
            }
        }
    }
    
    /// Cancel authentication
    func cancelAuthentication() {
        redirectHTTPHandler?.cancelHTTPListener()
    }
    
}
