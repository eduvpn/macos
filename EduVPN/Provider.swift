//
//  Provider.swift
//  EduVPN
//
//  Created by Johan Kool on 28/06/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
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
}

struct ProviderInfo {
    let apiBaseURL: URL
    let authorizationURL: URL
    let tokenURL: URL
}

struct Profile {
    let profileId: String
    let displayName: String
    let twoFactor: Bool
}
