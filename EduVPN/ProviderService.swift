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
    
    /// Returns discovery URL
    ///
    /// - Parameter connectionType: Connection type
    /// - Returns: URL
    private func url(for connectionType: ConnectionType) -> URL {
        let debug = true
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
        let task = URLSession.shared.dataTask(with: request) { (data, _, error) in
            guard let data = data else {
                handler(.failure(error ?? ProviderError.unknown))
                return
            }
            do {
                guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary else {
                    handler(.failure(ProviderError.invalidProviders))
                    return
                }
                
                guard let instances = json.value(forKeyPath: "instances") as? [[String: AnyObject]] else {
                    handler(.failure(ProviderError.invalidProviders))
                    return
                }
                
                let providers: [Provider] = instances.flatMap { (instance) -> Provider? in
                    guard let displayName = instance["display_name"] as? String,
                        let baseURL = URL(string: instance["base_uri"] as? String ?? ""),
                        let logoURL = URL(string: instance["logo_uri"] as? String ?? "") else {
                            return nil
                    }
                    let publicKey = instance["public_key"] as? String
                    
                    return Provider(displayName: displayName, baseURL: baseURL, logoURL: logoURL, publicKey: publicKey)
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
        let request = URLRequest(url: URL(string: "info.json", relativeTo:provider.baseURL)!)
        let task = URLSession.shared.dataTask(with: request) { (data, _, error) in
            guard let data = data else {
                handler(.failure(error ?? ProviderError.unknown))
                return
            }
            do {
                guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary else {
                    handler(.failure(ProviderError.invalidProviders))
                    return
                }
                
                guard let api = json.value(forKeyPath: "api.http://eduvpn.org/api#2") as? [String: AnyObject] else {
                    handler(.failure(ProviderError.invalidProviderInfo))
                    return
                }
                
                guard let apiBaseURL = URL(string: api["api_base_uri"] as? String ?? ""),
                    let authorizationURL = URL(string: api["authorization_endpoint"] as? String ?? ""),
                    let tokenURL = URL(string: api["token_endpoint"] as? String ?? "") else {
                        handler(.failure(ProviderError.invalidProviderInfo))
                        return
                }
                
                let providerInfo = ProviderInfo(apiBaseURL: apiBaseURL, authorizationURL: authorizationURL, tokenURL: tokenURL)
                handler(.success(providerInfo))
            } catch(let error) {
                handler(.failure(error))
                return
            }
        }
        task.resume()
    }

    func fetchProfiles(for info: ProviderInfo, authState: OIDAuthState, handler: @escaping (Either<[Profile]>) -> ()) {
    
    }
}

enum ProviderError: Error {
    case unknown
    case invalidProviders
    case invalidProviderInfo
}
