//
//  ProviderService.swift
//  EduVPN
//
//  Created by Johan Kool on 06/07/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

import Foundation
import AppAuth

/// Discovers providers
class ProviderService {
    
    enum Error: Swift.Error {
        case unknown
        case invalidProvider
        case noProviders
        case invalidProviders
        case invalidProviderInfo
        case noProfiles
        case invalidProfiles
        case missingToken
    }
    
    /// Returns discovery URL
    ///
    /// - Parameter connectionType: Connection type
    /// - Returns: URL
    private func url(for connectionType: ConnectionType) -> URL {
        let debug = UserDefaults.standard.bool(forKey: "developerMode")
        let path: String
        switch (connectionType, debug) {
        case (.secureInternet, false):
            path = "federation"
        case (.secureInternet, true):
            path = "federation-dev"
        case (.instituteAccess, false):
            path = "instances"
        case (.instituteAccess, true):
            path = "instances-dev"
        }
        return URL(string: path + ".json", relativeTo: URL(string: "https://static.eduvpn.nl/")!)!
    }
    
    /// Discovers providers for a connection type
    ///
    /// - Parameters:
    ///   - connectionType: Connection type
    ///   - handler: List of providers or error
    func discoverProviders(connectionType: ConnectionType, handler: @escaping (Either<[Provider]>) -> ()) {
        let request = URLRequest(url: url(for: connectionType))
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data, let response = response as? HTTPURLResponse, 200..<300 ~= response.statusCode else {
                handler(.failure(error ?? Error.unknown))
                return
            }
            do {
                guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary else {
                    handler(.failure(Error.invalidProviders))
                    return
                }
                
                guard let instances = json.value(forKeyPath: "instances") as? [[String: AnyObject]] else {
                    handler(.failure(Error.invalidProviders))
                    return
                }
                
                let providers: [Provider] = instances.flatMap { (instance) -> Provider? in
                    guard let displayName = instance["display_name"] as? String,
                        let baseURL = (instance["base_uri"] as? String)?.asURL(appendSlash: true),
                        let logoURL = (instance["logo_uri"] as? String)?.asURL() else {
                            return nil
                    }
                    let publicKey = instance["public_key"] as? String
                    
                    return Provider(displayName: displayName, baseURL: baseURL, logoURL: logoURL, publicKey: publicKey, connectionType: connectionType)
                }
                
                guard !providers.isEmpty else {
                    handler(.failure(Error.noProviders))
                    return
                }
                
                handler(.success(providers))
            } catch(let error) {
                handler(.failure(error))
                return
            }
        }
        task.resume()
    }
    
    /// Fetches info about provider
    ///
    /// - Parameters:
    ///   - provider: Provider
    ///   - handler: Info about provider or error
    func fetchInfo(for provider: Provider, handler: @escaping (Either<ProviderInfo>) -> ()) {
        guard let url = URL(string: "info.json", relativeTo: provider.baseURL) else {
            handler(.failure(Error.invalidProvider))
            return
        }
        
        let request = URLRequest(url:url)
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data, let response = response as? HTTPURLResponse, 200..<300 ~= response.statusCode else {
                handler(.failure(error ?? Error.unknown))
                return
            }
            do {
                guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary else {
                    handler(.failure(Error.invalidProviders))
                    return
                }
                
                guard let api = json.value(forKeyPath: "api.http://eduvpn.org/api#2") as? [String: AnyObject] else {
                    handler(.failure(Error.invalidProviderInfo))
                    return
                }
                
                guard let apiBaseURL = (api["api_base_uri"] as? String)?.asURL(appendSlash: true),
                    let authorizationURL = (api["authorization_endpoint"] as? String)?.asURL(),
                    let tokenURL = (api["token_endpoint"] as? String)?.asURL() else {
                        handler(.failure(Error.invalidProviderInfo))
                        return
                }
                
                let providerInfo = ProviderInfo(apiBaseURL: apiBaseURL, authorizationURL: authorizationURL, tokenURL: tokenURL, provider: provider)
                handler(.success(providerInfo))
            } catch(let error) {
                handler(.failure(error))
                return
            }
        }
        task.resume()
    }

    /// Fetches profiles available for provider
    ///
    /// - Parameters:
    ///   - info: Provider info
    ///   - authState: Authencation token
    ///   - handler: Profiles or error
    func fetchProfiles(for info: ProviderInfo, authState: OIDAuthState, handler: @escaping (Either<[Profile]>) -> ()) {
        guard let url = URL(string: "profile_list", relativeTo: info.apiBaseURL) else {
            handler(.failure(Error.invalidProviderInfo))
            return
        }
        
        authState.performAction { (accessToken, idToken, error) in
            guard let accessToken = accessToken else {
                handler(.failure(error ?? Error.missingToken))
                return
            }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                guard let data = data, let response = response as? HTTPURLResponse, 200..<300 ~= response.statusCode else {
                    handler(.failure(error ?? Error.unknown))
                    return
                }
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary else {
                        handler(.failure(Error.invalidProfiles))
                        return
                    }
                    
                    guard let instances = json.value(forKeyPath: "profile_list.data") as? [[String: AnyObject]] else {
                        handler(.failure(Error.invalidProfiles))
                        return
                    }
                    
                    let profiles: [Profile] = instances.flatMap { (instance) -> Profile? in
                        guard let displayName = instance["display_name"] as? String,
                            let profileId = instance["profile_id"] as? String else {
                                return nil
                        }
                        let twoFactor = instance["two_factor"] as? Bool
                        
                        return Profile(profileId: profileId, displayName: displayName, twoFactor: twoFactor ?? false, info: info)
                    }
                    
                    guard !profiles.isEmpty else {
                        handler(.failure(Error.noProfiles))
                        return
                    }
                    
                    handler(.success(profiles))
                } catch(let error) {
                    handler(.failure(error))
                    return
                }
            }
            task.resume()
        }
    }
    
}
