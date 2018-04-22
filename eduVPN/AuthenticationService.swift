//
//  AuthenticationService.swift
//  eduVPN
//
//  Created by Johan Kool on 06/07/2017.
//  Copyright © 2017 eduVPN. All rights reserved.
//

import Foundation
import AppKit
import AppAuth

/// Authorizes user with provider
class AuthenticationService {
    
    enum Error: Swift.Error, LocalizedError {
        case unknown
        case noToken
        
        var errorDescription: String? {
            switch self {
            case .unknown:
                return NSLocalizedString("Authorization failed for unknown reason", comment: "")
            case .noToken:
                return NSLocalizedString("Authorization failed", comment: "")
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .unknown:
                return NSLocalizedString("Try to authorize again with your provider.", comment: "")
            case .noToken:
                return NSLocalizedString("Try to add your provider again.", comment: "")
            }
        }
    }
    
    private var redirectHTTPHandler: OIDRedirectHTTPHandler?
    private let appName: String
    
    init(appName: String) {
        self.appName = appName
        readFromDisk()
    }
    
    /// Start authentication process with provider
    ///
    /// - Parameters:
    ///   - info: Provider info
    ///   - handler: Auth state or error
    func authenticate(using info: ProviderInfo, handler: @escaping (Result<OIDAuthState>) -> ()) {
        let configuration = OIDServiceConfiguration(authorizationEndpoint: info.authorizationURL, tokenEndpoint: info.tokenURL)
        
        redirectHTTPHandler = OIDRedirectHTTPHandler(successURL: nil)
        let redirectURL = URL(string: "callback", relativeTo: redirectHTTPHandler!.startHTTPListener(nil))!
        let request = OIDAuthorizationRequest(configuration: configuration, clientId: "org.eduvpn.app.macos", clientSecret: nil, scopes: ["config"], redirectURL: redirectURL, responseType: OIDResponseTypeCode, additionalParameters: nil)
        
        redirectHTTPHandler!.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request) { (authState, error) in
            NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            
            if let authState = authState {
                self.store(for: info.provider, authState: authState)
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
    
    /// Authentication tokens
    private var authStatesByProviderId: [String: OIDAuthState] = [:]
    private var authStatesByConnectionType: [ConnectionType: OIDAuthState] = [:]
    
    /// Finds authentication token
    ///
    /// - Parameter provider: Provider
    /// - Returns: Authentication token if available
    func authState(for provider: Provider) -> OIDAuthState? {
        switch provider.authorizationType {
        case .local:
            return authStatesByProviderId[provider.id]
        case .distributed, .federated:
            return authStatesByConnectionType[provider.connectionType]
        }
    }
    
    /// Performs an authenticated action
    ///
    /// - Parameters:
    ///   - info: Provider info
    ///   - reauthenticateIfNeeded: Whether authentication should retried when token is revoked or expired
    ///   - action: The action to perform
    func performAction(for info: ProviderInfo, reauthenticateIfNeeded: Bool = true, action: @escaping OIDAuthStateAction) {
        func reauthenticate() {
            authenticate(using: info, handler: { (result) in
                switch result {
                case .success:
                    self.performAction(for: info, reauthenticateIfNeeded: false, action: action)
                case .failure(let error):
                    action(nil, nil, error)
                }
            })
        }
        
        guard let authState = authState(for: info.provider) else {
            if reauthenticateIfNeeded {
                reauthenticate()
            } else {
                action(nil, nil, Error.noToken)
            }
            return
        }
        
        authState.performAction { (accessToken, idToken, error) in
            guard let accessToken = accessToken else {
                if reauthenticateIfNeeded {
                    reauthenticate()
                } else {
                    action(nil, idToken, error)
                }
                return
            }
            action(accessToken, idToken, error)
        }
    }
    
    /// Stores an authentication token
    ///
    /// - Parameters:
    ///   - info: Provider info
    ///   - authState: Authentication token
    private func store(for provider: Provider, authState: OIDAuthState) {
        switch provider.authorizationType {
        case .local:
            authStatesByProviderId[provider.id] = authState
        case .distributed, .federated:
            authStatesByConnectionType[provider.connectionType] = authState
        }
        saveToDisk()
    }
    
    /// URL for saving authentication tokens to disk
    ///
    /// - Returns: URL
    /// - Throws: Error finding or creating directory
    private func storedAuthStatesFileURL() throws -> URL  {
        var applicationSupportDirectory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        switch Bundle.main.bundleIdentifier! {
        case "org.eduvpn.app":
            applicationSupportDirectory.appendPathComponent("eduVPN")
        case "org.eduvpn.app.home":
            applicationSupportDirectory.appendPathComponent("Let's connect!")
        default:
            fatalError()
        }
        try FileManager.default.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true, attributes: nil)
        applicationSupportDirectory.appendPathComponent("AuthenticationTokens.plist")
        return applicationSupportDirectory
    }
    
    /// Reads authentication tokens from disk
    private func readFromDisk() {
        do {
            let url = try storedAuthStatesFileURL()
            let data = try Data(contentsOf: url)
            // OIDAuthState doesn't support Codable, use NSArchiving instead
            if let restoredAuthStates = NSKeyedUnarchiver.unarchiveObject(with: data) as? [String: AnyObject] {
                if let authStatesByProviderId = restoredAuthStates["authStatesByProviderId"] as? [String: OIDAuthState] {
                    self.authStatesByProviderId = authStatesByProviderId
                }
                if let authStatesByConnectionType = restoredAuthStates["authStatesByConnectionType"] as? [String: OIDAuthState] {
                    // Convert String to ConnectionType
                    self.authStatesByConnectionType = authStatesByConnectionType.reduce(into: [ConnectionType: OIDAuthState]()) { (result, entry) in
                        if let type = ConnectionType(rawValue: entry.key) {
                            result[type] = entry.value
                        }
                    }
                }
            } else {
                NSLog("Failed to unarchive stored authentication tokens from disk")
            }
        } catch (let error) {
            NSLog("Failed to read stored authentication tokens from disk: \(error)")
        }
    }
    
    /// Saves authentication tokens to disk
    private func saveToDisk() {
        do {
            // Convert ConnectionType to String
            let authStatesByConnectionType = self.authStatesByConnectionType.reduce(into: [String: OIDAuthState]()) { (result, entry) in
                result[entry.key.rawValue] = entry.value
            }
            let data = NSKeyedArchiver.archivedData(withRootObject: ["authStatesByProviderId": authStatesByProviderId, "authStatesByConnectionType": authStatesByConnectionType])
            let url = try storedAuthStatesFileURL()
            try data.write(to: url, options: .atomic)
        } catch (let error) {
            NSLog("Failed to save stored authentication tokens to disk: \(error)")
        }
    }
    
}
