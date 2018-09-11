//
//  AppConfig.swift
//  eduVPN
//
//  Created by Johan Kool on 10/09/2018.
//  Copyright © 2018 EduVPN. All rights reserved.
//

struct AppConfig: AppConfigType {
    
    var appName: String {
        return "eduVPN"
    }
    
    var clientId: String {
        return "org.eduvpn.app.macos"
    }
    
    var apiDiscoveryEnabled: Bool {
        return true
    }

}
