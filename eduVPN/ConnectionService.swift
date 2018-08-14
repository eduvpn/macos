//
//  ConnectionService.swift
//  eduVPN
//
//  Created by Johan Kool on 30/06/2017.
//  Copyright © 2017 eduVPN. All rights reserved.
//

import Foundation
import AppKit
import ServiceManagement
import AppAuth
import Socket

typealias Config = String

/// Connects to VPN
class ConnectionService: NSObject {
    
    static let openVPNSubdirectory = "openvpn-2.4.4-openssl-1.0.2o"
    
    /// Notification posted when connection state changes
    static let stateChanged = NSNotification.Name("ConnectionService.stateChanged")
    
    /// Connection state
    ///
    /// - connecting: Service is attempting to connect
    /// - connected: Service is connected
    /// - disconnecting: Service is attempting to disconnect
    /// - disconnected: Service is disconnected
    enum State: Equatable {
        case connecting
        case connected
        case disconnecting
        case disconnected
    }
    
    enum Error: Swift.Error, LocalizedError {
        case noHelperConnection
        case helperRejected
        case statisticsUnavailable
        case unexpectedState
        case logsUnavailable
        
        var errorDescription: String? {
            switch self {
            case .noHelperConnection:
                return NSLocalizedString("Installation failed", comment: "")
            case .helperRejected:
                return NSLocalizedString("Helper rejected request", comment: "")
            case .statisticsUnavailable:
                return NSLocalizedString("No connection statistics available", comment: "")
            case .unexpectedState:
                return NSLocalizedString("Connection in unexpected state", comment: "")
            case .logsUnavailable:
                return NSLocalizedString("No logs available", comment: "")
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .noHelperConnection:
                return NSLocalizedString("Try reinstalling eduVPN.", comment: "")
            case .helperRejected:
                return NSLocalizedString("Try reinstalling eduVPN.", comment: "")
            case .statisticsUnavailable, .logsUnavailable:
                return NSLocalizedString("Try again later.", comment: "")
            case .unexpectedState:
                return NSLocalizedString("Try again.", comment: "")
            }
        }
    }
 
    /// Describes current connection state
    private(set) var state: State = .disconnected {
        didSet {
            if oldValue != state {
                NotificationCenter.default.post(name: ConnectionService.stateChanged, object: self)
            }
        }
    }
    
    private let configurationService: ConfigurationService
    private let helperService: HelperService
    private let keychainService: KeychainService
    
    init(configurationService: ConfigurationService, helperService: HelperService, keychainService: KeychainService) {
        self.configurationService = configurationService
        self.helperService = helperService
        self.keychainService = keychainService
    }

    /// Asks helper service to start VPN connection after helper and config are ready and available
    ///
    /// - Parameters:
    ///   - profile: Profile
    ///   - twoFactor: Optional two factor authentication token
    ///   - authState: Authentication token
    ///   - handler: Success or error
    func connect(to profile: Profile, twoFactor: TwoFactor?, authState: OIDAuthState, handler: @escaping (Result<Void>) -> ()) {
        guard state == .disconnected else {
            handler(.failure(Error.unexpectedState))
            return
        }
        state = .connecting
        
        helperService.installHelperIfNeeded(client: self) { (result) in
            switch result {
            case .success:
                self.configurationService.configure(for: profile, authState: authState) { (result) in
                    switch result {
                    case .success(let config, let certificateCommonName):
                        do {
                            let configURL = try self.install(config: config)
                            let authUserPassURL: URL?
                            if let twoFactor = twoFactor {
                                authUserPassURL = try self.install(twoFactor: twoFactor)
                            } else {
                                authUserPassURL = nil
                            }
                            self.commonNameCertificate = certificateCommonName
                            self.activateConfig(at: configURL, authUserPassURL: authUserPassURL, handler: handler)
                        } catch(let error) {
                            self.state = .disconnected
                            handler(.failure(error))
                        }
                    case .failure(let error):
                        self.state = .disconnected
                        handler(.failure(error))
                    }
                }
            case .failure(let error):
                self.state = .disconnected
                handler(.failure(error))
            }
        }
    }

    /// Installs configuration
    ///
    /// - Parameter config: Config
    /// - Returns: URL where config was installed
    /// - Throws: Error writing config to disk
    private func install(config: String) throws -> URL {
        let tempDir = (NSTemporaryDirectory() as NSString).appendingPathComponent("org.eduvpn.app.temp") // Added .temp because .app lets the Finder show the folder as an app
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true, attributes: nil)
        let fileURL = URL(fileURLWithPath: (tempDir as NSString).appendingPathComponent("eduvpn.ovpn"))
        try config.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    /// Installs authUserPass
    ///
    /// - Parameter twoFactor: Two Factor Authenticationtoken
    /// - Returns: URL where authUserPass was installed
    /// - Throws: Error writing config to disk
    private func install(twoFactor: TwoFactor) throws -> URL {
        let username: String
        let password: String
        switch twoFactor {
        case .totp(let token):
            username = "totp"
            password = token
        case .yubico(let token):
            username = "yubi"
            password = token
        }
        
        let tempDir = (NSTemporaryDirectory() as NSString).appendingPathComponent("org.eduvpn.app.temp") // Added .temp because .app lets the Finder show the folder as an app
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true, attributes: nil)
        let fileURL = URL(fileURLWithPath: (tempDir as NSString).appendingPathComponent("eduvpn.aup"))
        try "\(username)\n\(password)".write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    /// Asks helper service to start VPN connection
    ///
    /// - Parameters:
    ///   - configURL: URL of config file
    ///   - handler: Succes or error
    private func activateConfig(at configURL: URL, authUserPassURL: URL?, handler: @escaping (Result<Void>) -> ()) {
        guard state == .connecting else {
            handler(.failure(Error.unexpectedState))
            return
        }
        
        guard let helper = helperService.connection?.remoteObjectProxy as? OpenVPNHelperProtocol else {
            handler(.failure(Error.noHelperConnection))
            return
        }
        
        let bundle = Bundle.init(for: ConnectionService.self)
        let openvpnURL = bundle.url(forResource: "openvpn", withExtension: nil, subdirectory: ConnectionService.openVPNSubdirectory)!
        let upScript = bundle.url(forResource: "client.up.eduvpn", withExtension: "sh", subdirectory: ConnectionService.openVPNSubdirectory)!
        let downScript = bundle.url(forResource: "client.down.eduvpn", withExtension: "sh", subdirectory: ConnectionService.openVPNSubdirectory)!
        self.configURL = configURL
        self.authUserPassURL = authUserPassURL
        helper.startOpenVPN(at: openvpnURL, withConfig: configURL, authUserPass: authUserPassURL, upScript: upScript, downScript: downScript) { (success) in
            if success {
                self.state = .connected
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.openManagingSocket()
                }
                handler(.success(Void()))
            } else {
                self.state = .disconnected
                self.configURL = nil
                self.authUserPassURL = nil
                handler(.failure(Error.helperRejected))
            }
        }
    }
    
    /// Uninstalls file
    ///
    /// - Parameter fileURL: URL where file was installed
    /// - Throws: Error removing file from disk
    private func uninstall(fileURL: URL) {
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch(let error) {
            print("Failed to remove file at URL %@ with error: %@", fileURL, error)
        }
    }
    
    /// Asks helper to disconnect VPN connection
    ///
    /// - Parameter handler: Success or error
    func disconnect(_ handler: @escaping (Result<Void>) -> ()) {
        guard state == .connected else {
            handler(.failure(Error.unexpectedState))
            return
        }
        
        state = .disconnecting
        
        guard let helper = helperService.connection?.remoteObjectProxy as? OpenVPNHelperProtocol else {
            self.state = .connected
            handler(.failure(Error.noHelperConnection))
            return
        }
        
        helper.close { 
            self.state = .disconnected
            self.configURL = nil
            self.authUserPassURL = nil
            handler(.success(Void()))
            self.closeManagingSocket()
        }
    }
    
    /// Asks helper for statistics about current VPN connection
    ///
    /// - Parameter handler: Statistics or error
    func readStatistics(_ handler: @escaping (Result<Statistics>) -> ()) {
        guard let helper = helperService.connection?.remoteObjectProxy as? OpenVPNHelperProtocol else {
            handler(.failure(Error.noHelperConnection))
            return
        }
        
        helper.readStatistics { (statistics) in
            if let statistics = statistics {
                handler(.success(statistics))
            } else {
                handler(.failure(Error.statisticsUnavailable))
            }
        }
    }
    
    /// Asks helper for logs about current VPN connection
    ///
    /// - Parameter handler: Logs or error
    func readLogs(_ handler: @escaping (Result<[String]>) -> ()) {
        guard let helper = helperService.connection?.remoteObjectProxy as? OpenVPNHelperProtocol else {
            handler(.failure(Error.noHelperConnection))
            return
        }
        
        helper.readLogs{ (logs) in
            if let logs = logs {
                handler(.success(logs))
            } else {
                handler(.failure(Error.logsUnavailable))
            }
        }
    }
    
    // Asks helper for IP addresses for current VPN connection
    ///
    /// - Parameter handler: IP addresses or error
    func findIPAddresses(_ handler: @escaping (Result<IPAddresses>) -> ()) {
        guard let helper = helperService.connection?.remoteObjectProxy as? OpenVPNHelperProtocol else {
            handler(.failure(Error.noHelperConnection))
            return
        }
        
        helper.readLogs { (logs) in
            if let logs = logs, let addresses = self.findIPAddresses(logs: logs) {
                handler(.success(addresses))
            } else {
                handler(.failure(Error.logsUnavailable))
            }
        }
    }
    
    private let controlMessageIndicator: String = "PUSH: Received control message:"
    
    private func findIPAddresses(logs: [String]) -> IPAddresses? {
        func extractControlMessage(_ log: String) -> String? {
            if let firstQuote = log.index(of: "'"),
                let lastQuote = log[log.index(firstQuote, offsetBy: 1)...].index(of: "'") {
                return String(log[firstQuote..<lastQuote])
            } else {
                return nil
            }
        }
        
        func extractLineComponents(key: String, from lines: [String.SubSequence]) -> [String] {
            if let line = lines.first(where: { $0.hasPrefix(key + " ") }) {
                let components = line.components(separatedBy: " ")
                return Array(components.suffix(from: 1))
            } else {
                return []
            }
        }
        
        func extractIPAddresses(_ lines: [String.SubSequence]) -> IPAddresses {
            let addresses = IPAddresses()
            
            if let ipv4Address = extractLineComponents(key: "ifconfig", from: lines).first {
                addresses.v4 = ipv4Address
            }
            
            if let ipv6Address = extractLineComponents(key: "ifconfig-ipv6", from: lines).first {
                addresses.v6 = ipv6Address
            }
            
            return addresses
        }
        
        for log in logs where log.contains(controlMessageIndicator) {
            if let controlMessage = extractControlMessage(log) {
                let lines = controlMessage.split(separator: ",")
                return extractIPAddresses(lines)
            }
        }
        
        return nil
    }
    
    /// URL to the last loaded config (which may have been deleted already!)
    private(set) var configURL: URL? {
        didSet(oldValue) {
            if let oldURL = oldValue {
                uninstall(fileURL: oldURL)
            }
        }
    }
    
    /// URL to the last loaded auth-user-pass (which may have been deleted already!)
    private(set) var authUserPassURL: URL? {
        didSet(oldValue) {
            if let oldURL = oldValue {
                uninstall(fileURL: oldURL)
            }
        }
    }
    
    /// URL to the log file
    var logURL: URL? {
        return configURL?.appendingPathExtension("log")
    }
    
    /// Path to socket
    private let socketPath = "/private/tmp/eduvpn.socket"
    
    private var socket: Socket?
    private var managing: Bool = false
    private var commonNameCertificate: String = ""
    
    func openManagingSocket() {
        guard !managing else {
            return
        }
        
        let queue = DispatchQueue.global(qos: .userInteractive)
        
        queue.async { [unowned self] in
            
            do {
                let socket = try Socket.create(family: .unix, type: .stream, proto: .unix)
                self.socket = socket
                
                try socket.connect(to: self.socketPath)
                self.managing = true
                repeat {
                    if let string = try socket.readString() {
                        print(string)
                        try self.parseRead(string)
                    }
                } while self.managing
               
            } catch (let error) {
                dump(error)
            }
            
        }

    }
    
    private func parseRead(_ string: String) throws {
        guard string.hasPrefix(">") else {
            // It's a response, not a command
            return
        }
        
        let components = string.split(separator: ":")
        
        guard let command = components.first else {
            return
        }
        
        switch String(command) {
        case ">INFO":
            break
        case ">NEED-CERTIFICATE":
           try needCertificate()
        case ">RSA_SIGN":
            guard let argumentSubstring = components.last else {
                return
            }
            let argument = String(argumentSubstring)
            try rsaSign(argument)
        default:
            break
        }
    }
    
    private func needCertificate() throws {
        let certificate = try self.keychainService.certificate(for: self.commonNameCertificate)
        let certificateString = certificate.base64EncodedString(options: [.lineLength64Characters])
        let response = "certificate\n-----BEGIN CERTIFICATE-----\n\(certificateString)\n-----END CERTIFICATE-----\nEND\n"
        print(response)
        try socket?.write(from: response)
    }
    
    private func rsaSign(_ stringToSign: String) throws {
        guard let data = stringToSign.data(using: .utf8) else {
            throw Error.helperRejected
        }
        let signature = try self.keychainService.sign(using: self.commonNameCertificate, dataToSign: data)
        let signatureString = signature.base64EncodedString(options: [.lineLength64Characters])
        let response = "rsa-sig\n\(signatureString)\nEND\n"
        
        try socket?.write(from: response)
    }
    
    func closeManagingSocket() {
        managing = false
        socket?.close()
    }
    
}

extension ConnectionService: ClientProtocol {
    
    func taskTerminated(reply: @escaping () -> Void) {
        self.state = .disconnecting
        reply()
        self.state = .disconnected
        self.configURL = nil
        self.authUserPassURL = nil
    }

}

