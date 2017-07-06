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
    
    static let AuthenticationInitiated: NSNotification.Name = NSNotification.Name("AuthenticationService.AuthenticationInitiated")
    static let AuthenticationCancelled: NSNotification.Name = NSNotification.Name("AuthenticationService.AuthenticationCancelled")
    static let AuthenticationSucceeded: NSNotification.Name = NSNotification.Name("AuthenticationService.AuthenticationSucceeded")

    private var redirectHTTPHandler: OIDRedirectHTTPHandler?
    private var authState: OIDAuthState?
    
    func authenticate(using info: ProviderInfo) throws {
        
        let configuration = OIDServiceConfiguration(authorizationEndpoint: info.authorizationURL, tokenEndpoint: info.tokenURL)
        
        redirectHTTPHandler = OIDRedirectHTTPHandler(successURL: nil) // URL(string: "org.eduvpn.app:/api/callback")!)
        let redirectURL = URL(string: "callback", relativeTo: redirectHTTPHandler!.startHTTPListener(nil))!
        let request = OIDAuthorizationRequest(configuration: configuration, clientId: "org.eduvpn.app", clientSecret: nil, scopes: ["config"], redirectURL: redirectURL, responseType: OIDResponseTypeCode, additionalParameters: nil)
        
        
        // performs authentication request
         redirectHTTPHandler!.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request) { (authState, error) in
            NSRunningApplication.current().activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            
            self.authState = authState
            
            if let authState = authState {
                NSLog("Got authorization tokens. Access token: \(authState.lastTokenResponse?.accessToken)")
                NotificationCenter.default.post(name: AuthenticationService.AuthenticationSucceeded, object: self)
                
            //    self.authenticationSucceeded()
            } else if let error = error {
                NSLog("Authorization error: \(error.localizedDescription)")
            }
        }
        
        NotificationCenter.default.post(name: AuthenticationService.AuthenticationInitiated, object: self)
        
    }
    
    func cancelAuthentication() {
        redirectHTTPHandler?.cancelHTTPListener()
        NotificationCenter.default.post(name: AuthenticationService.AuthenticationCancelled, object: self)
    }
    

    

}
