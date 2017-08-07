//
//  Provider.swift
//  eduVPN
//
//  Created by Johan Kool on 28/06/2017.
//  Copyright © 2017 eduVPN. All rights reserved.
//

import Foundation

enum ConnectionType {
    case secureInternet
    case instituteAccess
}

struct Provider {
    let displayName: String
    let baseURL: URL
    let logoURL: URL
    let publicKey: String?
    let connectionType: ConnectionType
}

struct ProviderInfo {
    let apiBaseURL: URL
    let authorizationURL: URL
    let tokenURL: URL
    let provider: Provider
}

struct Profile {
    let profileId: String
    let displayName: String
    let twoFactor: Bool
    let info: ProviderInfo
}
