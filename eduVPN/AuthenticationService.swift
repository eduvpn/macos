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
        
        var errorDescription: String? {
            switch self {
            case .unknown:
                return NSLocalizedString("Authorization failed for unknown reason", comment: "")
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .unknown:
                return NSLocalizedString("Try to authorize again with your provider.", comment: "")
            }
        }
    }
    
    private var redirectHTTPHandler: OIDRedirectHTTPHandler?
    
    init() {
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
        let request = OIDAuthorizationRequest(configuration: configuration, clientId: "org.eduvpn.app", clientSecret: nil, scopes: ["config"], redirectURL: redirectURL, responseType: OIDResponseTypeCode, additionalParameters: nil)
        
        redirectHTTPHandler!.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request) { (authState, error) in
            NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            
            if let authState = authState {
                self.store(info: info, authState: authState)
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
    private(set) var authStates: [String: OIDAuthState] = [:]
    
    /// Stores an authentication token
    ///
    /// - Parameters:
    ///   - info: Provider info
    ///   - authState: Authentication token
    private func store(info: ProviderInfo, authState: OIDAuthState) {
        authStates[info.provider.id] = authState
        saveToDisk()
    }
    
//    /// Removes profile and saves to disk
//    ///
//    /// - Parameter profile: profile
//    func deleteProfile(profile: Profile) {
//        let connectionType = profile.info.provider.connectionType
//        var profiles = storedProfiles[connectionType] ?? []
//        let index = profiles.index {
//            $0 == profile
//        }
//        if let index = index {
//            profiles.remove(at: index)
//            storedProfiles[connectionType] = profiles
//            saveToDisk()
//        }
//    }
    
    /// URL for saving authentication tokens to disk
    ///
    /// - Returns: URL
    /// - Throws: Error finding or creating directory
    private func storedAuthStatesFileURL() throws -> URL  {
        var applicationSupportDirectory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        applicationSupportDirectory.appendPathComponent("eduVPN")
        try FileManager.default.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true, attributes: nil)
        applicationSupportDirectory.appendPathComponent("AuthenticationTokens.plist")
        return applicationSupportDirectory
    }
    
    /// Reads authentication tokens from disk
    private func readFromDisk() {
        do {
            let url = try storedAuthStatesFileURL()
            let data = try Data(contentsOf: url)
            if let restoredAuthStates = NSKeyedUnarchiver.unarchiveObject(with: data) as? [String: OIDAuthState] {
                authStates = restoredAuthStates
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
            let data = NSKeyedArchiver.archivedData(withRootObject: authStates)
            let url = try storedAuthStatesFileURL()
            try data.write(to: url, options: .atomic)
        } catch (let error) {
            NSLog("Failed to write authentication tokens to disk: \(error)")
        }
    }
    
}

