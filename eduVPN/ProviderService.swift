//
//  ProviderService.swift
//  eduVPN
//
//  Created by Johan Kool on 06/07/2017.
//  Copyright © 2017 eduVPN. All rights reserved.
//

import Foundation
import AppAuth
import Sodium

/// Discovers providers
class ProviderService {
    
    enum Error: Swift.Error, LocalizedError {
        case unknown
        case invalidProvider
        case invalidProviderURL
        case noProviders
        case invalidProviders
        case invalidProviderInfo
        case providerVerificationFailed
        case noProfiles
        case invalidProfiles
        case missingToken
        
        var errorDescription: String? {
            switch self {
            case .unknown:
                return NSLocalizedString("Discovering providers failed for unknown reason", comment: "")
            case .invalidProvider:
                return NSLocalizedString("Invalid provider", comment: "")
            case .invalidProviderURL:
                return NSLocalizedString("Invalid provider URL", comment: "")
            case .noProviders:
                return NSLocalizedString("No providers were discovered", comment: "")
            case .invalidProviders:
                return NSLocalizedString("No valid providers were discovered", comment: "")
            case .invalidProviderInfo:
                return NSLocalizedString("Invalid provider info", comment: "")
            case .providerVerificationFailed:
                return NSLocalizedString("Could not verify providers", comment: "")
            case .noProfiles:
                return NSLocalizedString("No profiles were found for this provider", comment: "")
            case .invalidProfiles:
                return NSLocalizedString("Invalid profiles were found for this provider", comment: "")
            case .missingToken:
                return NSLocalizedString("Profiles could not be retrieved because no valid token was available", comment: "")
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .invalidProviderURL:
                return NSLocalizedString("Verify URL.", comment: "")
            default:
                return NSLocalizedString("Try again later.", comment: "")
            }
        }
    }
    
    init() {
        readFromDisk()
    }
    
    /// Discovers all providers that the user can access with the stored providers
    ///
    /// - Parameter handler: List of providers or error
    func discoverAccessibleProviders(handler: @escaping (Result<[ConnectionType: [Provider]]>) -> ()) {
        let group = DispatchGroup()
        var error: Error? = nil
        
        func discoverAvailableProviders(type: ConnectionType) {
            group.enter()
            discoverProviders(connectionType: type) { (result) in
                switch result {
                case .success(let providers):
                    self.availableProviders[type] = providers
                case .failure(let discoverError):
                    error = discoverError as? Error
                }
                group.leave()
            }
        }
        
        discoverAvailableProviders(type: .secureInternet)
        discoverAvailableProviders(type: .instituteAccess)
        
        group.notify(queue: .main) {
            if let error = error {
                handler(.failure(error))
                return
            }
            
            var accessibleProviders: [ConnectionType: [Provider]] = [:]
            
            func hasStoredDistributedProvider(type: ConnectionType) -> Bool {
                guard let providers = self.storedProviders[type] else {
                    return false
                }
                return providers.contains { (provider) -> Bool in
                    switch provider.authorizationType {
                    case .local:
                        return false
                    case .distributed, .federated:
                        return true
                    }
                }
            }
            
            func addProviders(type: ConnectionType) {
                if hasStoredDistributedProvider(type: type) {
                    // Add all providers
                    if let providers = self.availableProviders[type] {
                        accessibleProviders[type] = providers
                    }
                } else {
                    // Add stored providers
                    if let providers = self.storedProviders[type] {
                        accessibleProviders[type] = providers
                    }
                }
            }
            
            addProviders(type: .secureInternet)
            addProviders(type: .instituteAccess)
            addProviders(type: .custom)

            handler(.success(accessibleProviders))
        }
    }
    
    /// Indicates wether at least one provider is setup
    var hasAtLeastOneStoredProvider: Bool {
        return !storedProviders.isEmpty
    }
    
    /// All providers
    private var availableProviders: [ConnectionType: [Provider]] = [:]
    
    /// Providers with which the user has authenticated
    private(set) var storedProviders: [ConnectionType: [Provider]] = [:]
    
    /// Stores provider and saves it to disk
    ///
    /// - Parameter provider: provider
    func storeProvider(provider: Provider) {
        let connectionType = provider.connectionType
        var providers = storedProviders[connectionType] ?? []
        providers.append(provider)
        storedProviders[connectionType] = providers
        saveToDisk()
    }
    
    /// Removes provider and saves to disk
    ///
    /// - Parameter provider: provider
    func deleteProvider(provider: Provider) {
        let connectionType = provider.connectionType
        var providers = storedProviders[connectionType] ?? []
        let index = providers.index(where: { (otherProvider) -> Bool in
            return otherProvider.id == provider.id
        })
        if let index = index {
            providers.remove(at: index)
            storedProviders[connectionType] = providers
            saveToDisk()
        }
    }
    
    /// URL for saving providers to disk
    ///
    /// - Returns: URL
    /// - Throws: Error finding or creating directory
    private func storedProvidersFileURL() throws -> URL  {
        var applicationSupportDirectory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        applicationSupportDirectory.appendPathComponent("eduVPN")
        try FileManager.default.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true, attributes: nil)
        applicationSupportDirectory.appendPathComponent("Providers.plist")
        return applicationSupportDirectory
    }
    
    /// Reads providers from disk
    private func readFromDisk() {
        let decoder = PropertyListDecoder()
        do {
            let url = try storedProvidersFileURL()
            let data = try Data(contentsOf: url)
            let restoredProviders = try decoder.decode([ConnectionType: [Provider]].self, from: data)
            storedProviders = restoredProviders
        } catch (let error) {
            NSLog("Failed to read stored providers from disk at \(url): \(error)")
        }
    }
    
    /// Saves providers to disk
    private func saveToDisk() {
        let encoder = PropertyListEncoder()
        do {
            let data = try encoder.encode(storedProviders)
            let url = try storedProvidersFileURL()
            try data.write(to: url, options: .atomic)
        } catch (let error) {
            NSLog("Failed to write stored providers to disk at \(url): \(error)")
        }
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
            path = "secure_internet"
        case (.secureInternet, true):
            path = "secure_internet_dev"
        case (.instituteAccess, false):
            path = "institute_access"
        case (.instituteAccess, true):
            path = "institute_access_dev"
        case (.custom, _):
            fatalError("Can't discover custom providers")
        }
        return URL(string: path + ".json", relativeTo: URL(string: "https://static.eduvpn.nl/disco/")!)!
    }
    
    /// Returns discovery signature URL
    ///
    /// - Parameter connectionType: Connection type
    /// - Returns: URL
    private func signatureUrl(for connectionType: ConnectionType) -> URL {
        let debug = UserDefaults.standard.bool(forKey: "developerMode")
        let path: String
        switch (connectionType, debug) {
        case (.secureInternet, false):
            path = "secure_internet"
        case (.secureInternet, true):
            path = "secure_internet_dev"
        case (.instituteAccess, false):
            path = "institute_access"
        case (.instituteAccess, true):
            path = "institute_access_dev"
        case (.custom, _):
            fatalError("Can't discover custom provider signatures")
        }
        return URL(string: path + ".json.sig", relativeTo: URL(string: "https://static.eduvpn.nl/disco/")!)!
    }
    
    /// Discovers providers for a connection type
    ///
    /// - Parameters:
    ///   - connectionType: Connection type
    ///   - handler: List of providers or error
    func discoverProviders(connectionType: ConnectionType, handler: @escaping (Result<[Provider]>) -> ()) {
        let request = URLRequest(url: signatureUrl(for: connectionType))
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let signature = data, let response = response as? HTTPURLResponse, 200..<300 ~= response.statusCode else {
                handler(.failure(error ?? Error.unknown))
                return
            }
            discoverProviders(signature: signature)
        }
        task.resume()
        
        func discoverProviders(signature: Data) {
            let request = URLRequest(url: url(for: connectionType))
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                guard let data = data, let response = response as? HTTPURLResponse, 200..<300 ~= response.statusCode else {
                    handler(.failure(error ?? Error.unknown))
                    return
                }
                do {
                    let sodium = Sodium()
                    
                    guard let signatureBin = NSData(base64Encoded: signature, options: []) as Data? else {
                        handler(.failure(Error.providerVerificationFailed))
                        return
                    }
                    
                    let debug = UserDefaults.standard.bool(forKey: "developerMode")
                    let publicKeyString = debug ? "zzls4TZTXHEyV3yxaxag1DZw3tSpIdBoaaOjUGH/Rwg=" : "E5On0JTtyUVZmcWd+I/FXRm32nSq8R2ioyW7dcu/U88="
                    guard let publicKey = NSData(base64Encoded: publicKeyString, options: []) as Data? else {
                        handler(.failure(Error.providerVerificationFailed))
                        return
                    }
                    
                    guard sodium.sign.verify(message: data, publicKey: publicKey, signature: signatureBin) else {
                        handler(.failure(Error.invalidProviders))
                        return
                    }
                    
                    guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary else {
                        handler(.failure(Error.invalidProviders))
                        return
                    }
                    
                    let authorizationType: AuthorizationType
                    switch json["authorization_type"] as? String ?? "" {
                    case "local":
                        authorizationType = .local
                    case "distributed":
                        authorizationType = .distributed
                    case "federated":
                        guard let authorizationURL = (json["authorization_endpoint"] as? String)?.asURL(),
                            let tokenURL = (json["token_endpoint"] as? String)?.asURL() else {
                            handler(.failure(Error.invalidProviders))
                            return
                        }
                        authorizationType = .federated(authorizationURL: authorizationURL, tokenURL: tokenURL)
                    default:
                        handler(.failure(Error.invalidProviders))
                        return
                    }
                    
                    guard let instances = json.value(forKeyPath: "instances") as? [[String: AnyObject]] else {
                        handler(.failure(Error.invalidProviders))
                        return
                    }
                    
                    func displayName(for instance: [String: AnyObject]) -> String? {
                        if let displayName = instance["display_name"] as? String {
                            return displayName
                        } else if let localizedDisplayNames = instance["display_name"] as? [String: String] {
                            for (_, locale) in Locale.preferredLanguages.enumerated() {
                                if let displayName = localizedDisplayNames[locale] {
                                    return displayName
                                }
                            }
                            
                            // Language region combo, e.g. en-NL is not available, try to match on language only
                            for (_, locale) in Locale.preferredLanguages.enumerated() {
                                guard let languageSubstring = locale.split(separator: "-").first else {
                                    continue
                                }
                                let language = String(languageSubstring) 
                                for (key, displayName) in localizedDisplayNames {
                                    if key.hasPrefix(language) {
                                        return displayName
                                    }
                                }
                            }
                            
                            // Fallback
                            return localizedDisplayNames.values.first
                        }
                        
                        return nil
                    }
                    
                    let providers: [Provider] = instances.flatMap { (instance) -> Provider? in                        
                        guard let displayName = displayName(for: instance),
                            let baseURL = (instance["base_uri"] as? String)?.asURL(appendSlash: true),
                            let logoURL = (instance["logo"] as? String)?.asURL() else {
                                return nil
                        }
                        
                        let publicKey = instance["public_key"] as? String
                        
                        return Provider(displayName: displayName, baseURL: baseURL, logoURL: logoURL, publicKey: publicKey, connectionType: connectionType, authorizationType: authorizationType)
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
    }
    
    /// Fetches info about provider
    ///
    /// - Parameters:
    ///   - provider: Provider
    ///   - handler: Info about provider or error
    func fetchInfo(for provider: Provider, handler: @escaping (Result<ProviderInfo>) -> ()) {
        guard let url = URL(string: "info.json", relativeTo: provider.baseURL) else {
            handler(.failure(Error.invalidProvider))
            return
        }
        
        let request = URLRequest(url:url)
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data, let response = response as? HTTPURLResponse, 200..<300 ~= response.statusCode else {
                switch provider.connectionType {
                case .secureInternet, .instituteAccess:
                    handler(.failure(error ?? Error.unknown))
                case .custom:
                    handler(.failure(error ?? Error.invalidProviderURL))
                }
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
    ///   - authState: Authentication token
    ///   - handler: Profiles or error
    func fetchProfiles(for info: ProviderInfo, authState: OIDAuthState, handler: @escaping (Result<[Profile]>) -> ()) {
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
                        if twoFactor! {
                            NSLog("WARNING: 2FA not yet supported")
                            return nil
                        }
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
