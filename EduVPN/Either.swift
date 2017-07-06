//
//  Either.swift
//  EduVPN
//
//  Created by Johan Kool on 04/07/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

import Foundation

/// Either success or failure
///
/// - success: Success with associated value
/// - failure: Failure with associated error
enum Either<T> {
    case success(T)
    case failure(Error)
}
