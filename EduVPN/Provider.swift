//
//  Provider.swift
//  EduVPN
//
//  Created by Johan Kool on 28/06/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

import Foundation

struct Provider {
    let displayName: String
    let baseURL: URL
    let logoURL: URL
}

struct ProviderInfo {
    let apiBaseURL: URL
    let authorizationURL: URL
    let tokenURL: URL
}
