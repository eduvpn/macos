//
//  Either.swift
//  EduVPN
//
//  Created by Johan Kool on 04/07/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

import Foundation

enum Either<T> {
    case success(T)
    case failure(Error)
}
