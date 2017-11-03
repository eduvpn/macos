//
//  Provider.swift
//  eduVPN
//
//  Created by Johan Kool on 28/06/2017.
//  Copyright © 2017 eduVPN. All rights reserved.
//

import Foundation

enum ConnectionType: String, Codable {
    case secureInternet
    case instituteAccess
    
    var localizedDescription: String {
        switch self {
        case .secureInternet:
            return NSLocalizedString("Secure Internet", comment: "")
        case .instituteAccess:
            return NSLocalizedString("Institute Access", comment: "")
        }
    }
}

struct Provider: Codable {
    let displayName: String
    let baseURL: URL
    let logoURL: URL
    let publicKey: String?
    let connectionType: ConnectionType
    
    var id: String {
        return connectionType.rawValue + ":" + baseURL.absoluteString
    }
}

struct ProviderInfo: Codable {
    let apiBaseURL: URL
    let authorizationURL: URL
    let tokenURL: URL
    let provider: Provider
}

struct Profile: Codable {
    let profileId: String
    let displayName: String
    let twoFactor: Bool
    let info: ProviderInfo
}

