//
//  Debug.swift
//  eduVPN
//
//  Created by Johan Kool on 16/08/2018.
//  Copyright © 2018 EduVPN. All rights reserved.
//

import Foundation

func debugLog(_ items: Any...) {
    #if DEBUG
    print(items)
    #endif
}

