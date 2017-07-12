//
//  String+URL.swift
//  EduVPN
//
//  Created by Johan Kool on 07/07/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

import Foundation

extension String {
    
    func asURL(appendSlash slash: Bool = false) -> URL? {
        if slash && !hasSuffix("/") {
            return URL(string: self + "/")
        } else {
            return URL(string: self)
        }
    }
    
}
