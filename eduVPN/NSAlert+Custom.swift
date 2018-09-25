//
//  NSAlert+Custom.swift
//  eduVPN
//
//  Created by Johan Kool on 24/09/2018.
//  Copyright © 2018 EduVPN. All rights reserved.
//

import AppKit

extension NSAlert {
    
    convenience init?(customizedError error: Error) {
        switch ((error as NSError).domain, (error as NSError).code) {
        case ("org.openid.appauth.general", -4),
             ("org.openid.appauth.oauth_authorization", -4):
            return nil
        case (NSURLErrorDomain, NSURLErrorServerCertificateUntrusted):
            var userInfo = (error as NSError).userInfo
            userInfo[NSLocalizedRecoverySuggestionErrorKey] = NSLocalizedString("Contact the server administrator to request replacing the invalid certificate with a valid certificate.", comment: "")
            let customizedError = NSError(domain: (error as NSError).domain, code: (error as NSError).code, userInfo: userInfo)
            self.init(error: customizedError)
        default:
            self.init(error: error)
        }
    }
    
}
