//
//  KeychainService.swift
//  eduVPN
//
//  Created by Johan Kool on 06/06/2018.
//  Copyright © 2018 EduVPN. All rights reserved.
//

import Foundation

class KeychainService {
    
    enum Error: Swift.Error, LocalizedError {
        case unknown
        case unknownCommonName(String)
        case importError(Int32)
        case privateKeyError(Int32)
        case unsupportedAlgorithm
        
        var errorDescription: String? {
            switch self {
            case .unknownCommonName(let commonName):
                return NSLocalizedString("No certificate with common name \"\(commonName)\" found", comment: "")
            case .importError(let osstatus):
                return NSLocalizedString("An import error occurred \(osstatus)", comment: "")
            case .privateKeyError(let osstatus):
                return NSLocalizedString("Private key error occurred \(osstatus)", comment: "")
            case .unsupportedAlgorithm:
                return NSLocalizedString("The requested key algorithm is not supported", comment: "")
            default:
                return NSLocalizedString("An unknown error occurred", comment: "")
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .unknownCommonName:
                return NSLocalizedString("Add the missing certificate to your keychain.", comment: "")
            case .importError:
                return NSLocalizedString("Try again.", comment: "")
            case .privateKeyError:
                return NSLocalizedString("Try again.", comment: "")
            case .unsupportedAlgorithm:
                return NSLocalizedString("Check for app updates.", comment: "")
            default:
                return NSLocalizedString("Try again later.", comment: "")
            }
        }
    }
    
    func importKeyPair(data: Data, passphrase: String) throws -> String {
        let options: NSDictionary = [kSecImportExportPassphrase: passphrase]
        
        var items : CFArray?
        
        let importError = SecPKCS12Import(data as CFData, options, &items)
        guard importError == noErr else {
            throw Error.importError(importError)
        }
        
        let theArray: CFArray = items!
        guard CFArrayGetCount(theArray) > 0 else {
            throw Error.unknown
        }
        
        let newArray = theArray as [AnyObject] as NSArray
        let dictionary = newArray.object(at: 0)
        let secIdentity = (dictionary as AnyObject)[kSecImportItemIdentity as String] as! SecIdentity
        
        return try commonName(for: secIdentity)
    }
    
    private func identity(for commonName: String) throws -> SecIdentity {
        var secureItemValue: AnyObject? = nil
        let query: NSDictionary = [kSecClass: kSecClassIdentity, kSecMatchSubjectWholeString: commonName]
        let queryError = SecItemCopyMatching(query, &secureItemValue)
        guard queryError == noErr else {
            throw Error.unknownCommonName(commonName)
        }
        return secureItemValue as! SecIdentity
    }
    
    func certificate(for commonName: String) throws -> Data {
        let secIdentity = try identity(for: commonName)
        return try certificate(for: secIdentity)
    }
    
    func certificate(for secIdentity: SecIdentity) throws -> Data {
        var certificateRef: SecCertificate? = nil
        let securityError = SecIdentityCopyCertificate(secIdentity , &certificateRef)
        if securityError != noErr {
            certificateRef = nil
        }
        
        let dataOut = SecCertificateCopyData(certificateRef!)
        return dataOut as Data
    }
    
    func commonName(for secIdentity: SecIdentity) throws -> String {
        var certificateRef: SecCertificate? = nil
        let certificateError = SecIdentityCopyCertificate(secIdentity, &certificateRef)
        guard certificateError == noErr else {
            throw Error.unknown
        }
        
        var commonName: CFString? = nil
        let commonNameError = SecCertificateCopyCommonName(certificateRef!, &commonName)
        guard commonNameError == noErr else {
            throw Error.unknown
        }
        return commonName! as String
    }
    
    func sign(using commonName: String, dataToSign: Data) throws -> Data {
        let secIdentity = try identity(for: commonName)
        
        var secKey: SecKey? = nil
        let privateKeyError = SecIdentityCopyPrivateKey(secIdentity, &secKey)
        guard privateKeyError == noErr else {
            throw Error.privateKeyError(privateKeyError)
        }
        
        let algorithm: SecKeyAlgorithm = .rsaSignatureDigestPKCS1v15Raw

        guard SecKeyIsAlgorithmSupported(secKey!, .sign, algorithm) else {
            throw Error.unsupportedAlgorithm
        }
       
        var error: Unmanaged<CFError>? = nil
        guard let signature = SecKeyCreateSignature(secKey!, algorithm, dataToSign as CFData, &error) else {
            throw Error.unknown
        }

        return signature as Data
    }
}
