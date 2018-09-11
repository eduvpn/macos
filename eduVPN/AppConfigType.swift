//
//  AppConfigType.swift
//  eduVPN
//
//  Created by Johan Kool on 10/09/2018.
//  Copyright © 2018 EduVPN. All rights reserved.
//

protocol AppConfigType {
    
    var appName: String { get }
    var clientId: String { get }
    
    var apiDiscoveryEnabled: Bool { get }

}
