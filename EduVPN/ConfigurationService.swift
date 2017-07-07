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
    
    enum Error: Swift.Error {
        case unknown
        case notImplemented
        case invalidURL
        case missingToken
        case invalidKeyPair
        case invalidConfiguration
    }
    
    func configure(for profile: Profile, authState: OIDAuthState, handler: @escaping (Either<Config>) -> ()) {
        restoreOrCreateKeyPair(for: profile, authState:  authState) { (result) in
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
    
    private func restoreOrCreateKeyPair(for profile: Profile, authState: OIDAuthState, handler: @escaping (Either<(certificate: String, privateKey: String)>) -> ()) {
        // TODO: restore key pair
        createKeyPair(for: profile, authState: authState, handler: handler)
    }
    
    private func createKeyPair(for profile: Profile, authState: OIDAuthState, handler: @escaping (Either<(certificate: String, privateKey: String)>) -> ()) {
        guard let url = URL(string: "create_keypair", relativeTo: profile.info.apiBaseURL) else {
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
    
    private func fetchConfig(for profile: Profile, authState: OIDAuthState, handler: @escaping (Either<Config>) -> ()) {
        // TODO: Properly escape profile_id / construct URL using URLComponents
        guard let url = URL(string: "profile_config?profile_id=\(profile.profileId)", relativeTo: profile.info.apiBaseURL) else {
            handler(.failure(Error.invalidURL))
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
                
                guard let config = String(data: data, encoding: .utf8) else {
                    handler(.failure(Error.invalidConfiguration))
                    return
                }
                
                handler(.success(config))
            }
            task.resume()
        }
    }
    
    private func consolidate(config: Config, certificate: String, privateKey: String) -> Config {
        return config + "\n<cert>\n" + certificate + "\n</cert>\n<key>\n" + privateKey + "\n</key>"
    }
    
}
