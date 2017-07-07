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
        case notImplemented
    }
    
    func configure(for profile: Profile, authState: OIDAuthState, handler: @escaping (Either<Config>) -> ()) {
        handler(.failure(Error.notImplemented))
//            createKeyPair(using: providerInfo) { (result) in
//                switch result {
//                case .success((let certificate, let privateKey)):
//                    try? self.fetchProfile(using: providerInfo) { (result) in
//                        switch result {
//                        case .success(let config):
//                            let profileConfig = self.consolidate(config: config, certificate: certificate, privateKey: privateKey)
////                            let profileURL = try! self.install(config: profileConfig)
////                            self.activateConfig(at: profileURL)
//                            break
//                        case .failure(let error):
//                            break
//                        }
//                    }
//                    break
//                case .failure(let error):
//                    
//                    break
//                }
//            }
 
    }
    
    private func createKeyPair(using info: ProviderInfo, authState: OIDAuthState, handler: @escaping (Either<(certificate: String, privateKey: String)>) -> ()) {
        handler(.failure(Error.notImplemented))

//        guard let url = URL(string: "create_keypair", relativeTo: info.apiBaseURL) else {
//            throw ConnectionError.invalidURL
//        }
//        
//        authState?.performAction() { (accessToken, idToken, error) in
//            guard let accessToken = accessToken else {
//                fatalError()
//            }
//            
//            var request = URLRequest(url: url)
//            request.httpMethod = "POST"
//            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
//            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
//            let data = "display_name=test".data(using: .utf8)!
//            request.httpBody = data
//            request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
//            
//            let task = URLSession.shared.dataTask(with: request) { (data, _, error) in
//                guard let data = data else {
//                    handler(.failure(error ?? ConnectionError.unknown))
//                    return
//                }
//                do {
//                    guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary else {
//                        handler(.failure(ConnectionError.invalidKeyPair))
//                        return
//                    }
//                    
//                    guard let certificate = json.value(forKeyPath: "create_keypair.data.certificate") as? String else {
//                        handler(.failure(ConnectionError.invalidKeyPair))
//                        return
//                    }
//                    
//                    guard let privateKey = json.value(forKeyPath: "create_keypair.data.private_key") as? String else {
//                        handler(.failure(ConnectionError.invalidKeyPair))
//                        return
//                    }
//                    
//                    handler(.success((certificate: certificate, privateKey: privateKey)))
//                } catch(let error) {
//                    handler(.failure(error))
//                    return
//                }
//            }
//            task.resume()
//            
//        }
        
    }
    
    
    private func fetchProfile(using info: ProviderInfo, id: String = "internet", authState: OIDAuthState, handler: @escaping (Either<String>) -> ()) {
        handler(.failure(Error.notImplemented))

//        guard let url = URL(string: "profile_config?profile_id=\(id)", relativeTo: info.apiBaseURL) else {
//            throw ConnectionError.invalidURL
//        }
//        
//        authState?.performAction() { (accessToken, idToken, error) in
//            guard let accessToken = accessToken else {
//                fatalError()
//            }
//            var request = URLRequest(url: url)
//            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
//            
//            let task = URLSession.shared.dataTask(with: request) { (data, _, error) in
//                guard let data = data else {
//                    handler(.failure(error ?? ConnectionError.unknown))
//                    return
//                }
//                
//                guard let config = String(data: data, encoding: .utf8) else {
//                    handler(.failure(ConnectionError.invalidConfiguration))
//                    return
//                }
//                
//                handler(.success(config))
//            }
//            task.resume()
//        }
    }
    
    private func consolidate(config: String, certificate: String, privateKey: String) -> String {
        return config + "\n<cert>\n" + certificate + "\n</cert>\n<key>\n" + privateKey + "\n</key>"
    }
    
}
