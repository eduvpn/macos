//
//  Token.swift
//  EduVPN
//
//  Created by Johan Kool on 30/06/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

import Foundation

struct Token {
    
    enum TokenType: String {
        case bearer
    }
    
    let accessToken: String
    let type: TokenType
    let expiresOn: Date
    let state: String
    
}
