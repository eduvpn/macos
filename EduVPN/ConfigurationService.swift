//
//  ConfigurationService.swift
//  EduVPN
//
//  Created by Johan Kool on 06/07/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

import Foundation
import AppAuth

/// Fetches configuration
class ConfigurationService {
    
    enum Error: Swift.Error, LocalizedError {
        case unknown
        case invalidURL
        case missingToken
        case invalidKeyPair
        case invalidConfiguration
        
        var errorDescription: String? {
            switch self {
            case .unknown:
                return NSLocalizedString("Configuration failed for unknown reason", comment: "")
            case .invalidURL:
                return NSLocalizedString("Configuration failed because provider info was invalid", comment: "")
            case .missingToken:
                return NSLocalizedString("Configuration could not be retrieved because no valid token was available", comment: "")
            case .invalidKeyPair:
                return NSLocalizedString("Invalid keypair received from provider", comment: "")
            case .invalidConfiguration:
                return NSLocalizedString("Invalid configuration received from provider", comment: "")
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .unknown:
                return NSLocalizedString("Try to connect again.", comment: "")
            case .invalidURL:
                return NSLocalizedString("Go back to the first screen and try again.", comment: "")
            case .missingToken:
                return NSLocalizedString("Try to authorize again with your provider.", comment: "")
            case .invalidKeyPair:
                return NSLocalizedString("Try to connect again later.", comment: "")
            case .invalidConfiguration:
                return NSLocalizedString("Try to connect again later.", comment: "")
            }
        }
    }
    
    /// Fetches configuration for a profile including certificate and private key
    ///
    /// - Parameters:
    ///   - profile: Profile
    ///   - authState: Authencation token
    ///   - handler: Config or error
    func configure(for profile: Profile, authState: OIDAuthState, handler: @escaping (Result<Config>) -> ()) {
        restoreOrCreateKeyPair(for: profile.info, authState:  authState) { (result) in
            switch result {
            case .success((let certificate, let privateKey)):
                self.fetchConfig(for: profile, authState: authState) { (result) in
                    switch result {
                    case .success(let config):
                        let profileConfig = self.consolidate(config: config, certificate: certificate, privateKey: privateKey)
                        handler(.success(profileConfig))
                    case .failure(let error):
                        handler(.failure(error))
                    }
                }
            case .failure(let error):
                handler(.failure(error))
            }
        }
    }
    
    /// Checks if keypair is available for provider, otherwise creates and stores new keypair
    ///
    /// - Parameters:
    ///   - info: Provider info
    ///   - authState: Authencation token
    ///   - handler: Keypair or error
    private func restoreOrCreateKeyPair(for info: ProviderInfo, authState: OIDAuthState, handler: @escaping (Result<(certificate: String, privateKey: String)>) -> ()) {
        // TODO: restore key pair from keychain instead of user defaults
        var keyPairs = UserDefaults.standard.array(forKey: "keyPairs") ?? []
        
        let pairs = keyPairs.lazy.flatMap { keyPair -> (certificate: String, privateKey: String)? in
            guard let keyPair = keyPair as? [String: AnyObject] else {
                return nil
            }
            
            guard let providerBaseURL = keyPair["providerBaseURL"] as? String, info.provider.baseURL.absoluteString == providerBaseURL else {
                return nil
            }
            
            guard let certificate = keyPair["certificate"] as? String else {
                return nil
            }
            
            guard let privateKey = keyPair["privateKey"] as? String else {
                return nil
            }
            
            return (certificate, privateKey)
        }
        
        if let keyPair = pairs.first {
            handler(.success(keyPair))
        } else {
            // No key pair found, create new one and store it
            createKeyPair(for: info, authState: authState) { result in
                switch result {
                case .success((let certificate, let privateKey)):
                    // TODO: store key pair in keychain instead of user defaults
                    let keyPair = ["provider": info.provider.displayName, "providerBaseURL": info.provider.baseURL.absoluteString, "certificate": certificate, "privateKey": privateKey]
                    keyPairs.append(keyPair)
                    UserDefaults.standard.set(keyPairs, forKey: "keyPairs")
                    handler(.success((certificate: certificate, privateKey: privateKey)))
                case .failure(let error):
                    handler(.failure(error))
                }
            }
        }
    }
    
    /// Creates keypair with provider
    ///
    /// - Parameters:
    ///   - info: Provider info
    ///   - authState: Authencation token
    ///   - handler: Keypair or error
    private func createKeyPair(for info: ProviderInfo, authState: OIDAuthState, handler: @escaping (Result<(certificate: String, privateKey: String)>) -> ()) {
        guard let url = URL(string: "create_keypair", relativeTo: info.apiBaseURL) else {
            handler(.failure(Error.invalidURL))
            return
        }
        
        authState.performAction { (accessToken, idToken, error) in
            guard let accessToken = accessToken else {
                handler(.failure(error ?? Error.missingToken))
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            let data = "display_name=EduVPN%20(macOS)".data(using: .utf8)!
            request.httpBody = data
            request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
            
            let task = URLSession.shared.dataTask(with: request) { (data, _, error) in
                guard let data = data else {
                    handler(.failure(error ?? Error.unknown))
                    return
                }
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary else {
                        handler(.failure(Error.invalidKeyPair))
                        return
                    }
                    
                    guard let certificate = json.value(forKeyPath: "create_keypair.data.certificate") as? String else {
                        handler(.failure(Error.invalidKeyPair))
                        return
                    }
                    
                    guard let privateKey = json.value(forKeyPath: "create_keypair.data.private_key") as? String else {
                        handler(.failure(Error.invalidKeyPair))
                        return
                    }
                    
                    handler(.success((certificate: certificate, privateKey: privateKey)))
                } catch(let error) {
                    handler(.failure(error))
                    return
                }
            }
            task.resume()
        }
    }
    
    /// Fetches config from provider
    ///
    /// - Parameters:
    ///   - profile: Profile
    ///   - authState: Authencation token
    ///   - handler: Config or error
    private func fetchConfig(for profile: Profile, authState: OIDAuthState, handler: @escaping (Result<Config>) -> ()) {
        guard let url = URL(string: "profile_config", relativeTo: profile.info.apiBaseURL) else {
            handler(.failure(Error.invalidURL))
            return
        }
        
        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            handler(.failure(Error.invalidURL))
            return
        }
        
        var queryItems = urlComponents.queryItems ?? []
        queryItems.append(URLQueryItem(name: "profile_id", value: profile.profileId))
        urlComponents.queryItems = queryItems
        
        guard let requestUrl = urlComponents.url else {
            handler(.failure(Error.invalidURL))
            return
        }

        authState.performAction { (accessToken, idToken, error) in
            guard let accessToken = accessToken else {
                handler(.failure(error ?? Error.missingToken))
                return
            }
            var request = URLRequest(url: requestUrl)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                guard let data = data, let response = response as? HTTPURLResponse, 200..<300 ~= response.statusCode else {
                    handler(.failure(error ?? Error.unknown))
                    return
                }
                
                guard let config = String(data: data, encoding: .utf8) else {
                    handler(.failure(Error.invalidConfiguration))
                    return
                }
                
                handler(.success(config))
            }
            task.resume()
        }
    }
    
    /// Combines configuration with keypair
    ///
    /// - Parameters:
    ///   - config: Config
    ///   - certificate: Certificate
    ///   - privateKey: Private key
    /// - Returns: Configuration including keypair
    private func consolidate(config: Config, certificate: String, privateKey: String) -> Config {
        return config + "\n<cert>\n" + certificate + "\n</cert>\n<key>\n" + privateKey + "\n</key>"
    }
    
}
