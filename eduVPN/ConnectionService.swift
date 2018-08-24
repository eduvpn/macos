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
    
    static let openVPNSubdirectory = "openvpn-2.4.6-openssl-1.1.0h"
    
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
        case unexpectedError
        
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
            case .unexpectedError:
                return NSLocalizedString("Connection encountered unexpected error", comment: "")
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
            case .unexpectedState, .unexpectedError:
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
        
        // Reset
        bytesIn = 0
        bytesOut = 0
        startDate = Date()
        openVPNState = .unknown
        openVPNStateDescription = nil
        localTUNTAPIPv4Address = nil
        remoteIPv4Address = nil
        remotePort = nil
        localIPv4Address = nil
        localPort = nil
        localTUNTAPIPv6Address = nil
        
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
        let scriptOptions = [
            "-6" /* ARG_ENABLE_IPV6_ON_TAP */,
            "-f" /* ARG_FLUSH_DNS_CACHE */,
            "-l" /* ARG_EXTRA_LOGGING */,
            "-o" /* ARG_OVERRIDE_MANUAL_NETWORK_SETTINGS */,
            "-r" /* ARG_RESET_PRIMARY_INTERFACE_ON_DISCONNECT */,
            "-w" /* ARG_RESTORE_ON_WINS_RESET */
        ]
        self.configURL = configURL
        self.authUserPassURL = authUserPassURL
        helper.startOpenVPN(at: openvpnURL, withConfig: configURL, authUserPass: authUserPassURL, upScript: upScript, downScript: downScript, scriptOptions: scriptOptions) { (success) in
            if success {
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
            self.configURL = nil
            self.authUserPassURL = nil
            handler(.success(Void()))
        }
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
    
    // MARK: - Socket
    
    /// Path to socket
    private let socketPath = "/private/tmp/eduvpn.socket"
    
    private var socket: Socket?
    private var managing: Bool = false
    private var commonNameCertificate: String = ""
    
    private func openManagingSocket() {
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
              
                try _ = Socket.wait(for: [socket], timeout: 10_000 /* ms */)
                
                repeat {
                    if let string = try socket.readString() {
                        try self.parseRead(string)
                    }
                } while self.managing
               
            } catch {
                debugLog(error)
            }
            
        }

    }
    
    // See https://github.com/OpenVPN/openvpn/blob/master/doc/management-notes.txt
    private func parseRead(_ string: String) throws {
        let stringToParse: String
        let remainder: String?
        
        if let range = string.range(of: "\r\n>") {
            // Multiple commands in string, split and parse separately
            let index = string.index(range.upperBound, offsetBy: -1)
            stringToParse = String(string[..<index])
            remainder = String(string[index...])
        } else {
            stringToParse = string
            remainder = nil
        }
        
        guard stringToParse.hasPrefix(">") else {
            // It's a response, not a command
            debugLog("<<< " + stringToParse)
            if let remainder = remainder {
                try parseRead(remainder)
            }
            return
        }
        
        debugLog("CMD " + stringToParse)
        
        let argumentString: String?
        if let start = stringToParse.range(of: ":")?.upperBound {
            let end = stringToParse.range(of: "\r\n")?.lowerBound ?? stringToParse.endIndex
            argumentString = String(stringToParse[start..<end])
        } else {
            argumentString = nil
        }
        
        let components = stringToParse.split(separator: ":")
        
        guard let command = components.first else {
            return
        }
        
        switch String(command) {
        case ">INFO":
            try enableStateAndByteCountNotificatons()
        case ">NEED-CERTIFICATE":
           try needCertificate()
        case ">RSA_SIGN":
            guard let argumentString = argumentString else {
                return
            }
            try rsaSign(argumentString)
        case ">STATE":
            guard let argumentString = argumentString else {
                return
            }
            parseState(argumentString)
        case ">BYTECOUNT":
            guard let argumentString = argumentString else {
                return
            }
            parseByteCounts(argumentString)
        default:
            break
        }
        
        if let remainder = remainder {
            try parseRead(remainder)
        }
    }
    
    private func write(_ string: String) throws {
        debugLog(">>> " + string)
        try socket?.write(from: string)
    }
    
    private func enableStateAndByteCountNotificatons() throws {
        try write("state on\nbytecount 1\n")
    }
    
    enum OpenVPNState: String {
        case unknown
        case connecting = "CONNECTING"      // OpenVPN's initial state.
        case waiting = "WAIT"               // (Client only) Waiting for initial response from server.
        case authenticating = "AUTH"        // (Client only) Authenticating with server.
        case fetchingConfig = "GET_CONFIG"  // (Client only) Downloading configuration options from server.
        case assigningIP = "ASSIGN_IP"      // Assigning IP address to virtual network interface.
        case addingRoutes = "ADD_ROUTES"    // Adding routes to system.
        case connected = "CONNECTED"        // Initialization Sequence Completed.
        case reconnecting = "RECONNECTING"  // A restart has occurred.
        case exiting = "EXITING"            // A graceful exit is in progress.
        case resolving = "RESOLVE"          // (Client only) DNS lookup
        case connectingTCP = "TCP_CONNECT"  // (Client only) Connecting to TCP server
        
        var localizedDescription: String? {
            switch self {
            case .unknown:
                return nil
            case .connecting:
                return NSLocalizedString("Connecting", comment: "")
            case .waiting:
                return NSLocalizedString("Waiting for initial response from server", comment: "")
            case .authenticating:
                return NSLocalizedString("Authenticating with server", comment: "")
            case .fetchingConfig:
                return NSLocalizedString("Downloading configuration options from server", comment: "")
            case .assigningIP:
                return NSLocalizedString("Assigning IP address to virtual network interface", comment: "")
            case .addingRoutes:
                return NSLocalizedString("Adding routes to system", comment: "")
            case .connected:
                return NSLocalizedString("Connected", comment: "")
            case .reconnecting:
                return NSLocalizedString("Reconnecting", comment: "")
            case .exiting:
                return NSLocalizedString("Disconnected", comment: "")
            case .resolving :
                return NSLocalizedString("Performing DNS lookup", comment: "")
            case .connectingTCP:
                return NSLocalizedString("Connecting to TCP server", comment: "")
            }
        }
    }
    
    private(set) var openVPNState: OpenVPNState = .unknown {
        didSet {
            switch openVPNState {
            case .connected:
                state = .connected
            case .reconnecting:
                state = .connecting
            case .exiting:
                state = .disconnected
            default:
                break
            }
        }
    }
    private(set) var openVPNStateDescription: String? = nil
    private(set) var localTUNTAPIPv4Address: String?
    private(set) var remoteIPv4Address: String?
    private(set) var remotePort: String?
    private(set) var localIPv4Address: String?
    private(set) var localPort: String?
    private(set) var localTUNTAPIPv6Address: String?
    
    private func parseState(_ string: String) {
        let components = string.components(separatedBy: ",")
        guard components.count >= 8 else {
            // When returning certain states OpenVPN forgets one comma
            return
        }
        
        // The output format consists of up to 9 comma-separated parameters:
        
        // (a) the integer unix date/time
        // ignored
        
        // (b) the state name,
        openVPNState = OpenVPNState(rawValue: String(components[1])) ?? .unknown
        
        // (c) optional descriptive string (used mostly on RECONNECTING and EXITING to show the reason for the disconnect)
        openVPNStateDescription = String(components[2])
        
        // (d) optional TUN/TAP local IPv4 address
        localTUNTAPIPv4Address = String(components[3])
        
        // (e) optional address of remote server
        remoteIPv4Address = String(components[4])
        
        // (f) optional port of remote server
        remotePort = String(components[5])
        
        // (g) optional local address
        localIPv4Address = String(components[6])
        
        // (h) optional local port
        localPort = String(components[7])
        
        guard components.count == 9 else {
            // Unexpected number of parameters
            return
        }
        
        // (i) optional TUN/TAP local IPv6 address.
        localTUNTAPIPv6Address = String(components[8])
    }
    
    private(set) var bytesIn: Int = 0
    private(set) var bytesOut: Int = 0
    private var startDate: Date = Date()
    var duration: DateComponents {
        return Calendar.current.dateComponents([.hour, .minute, .second], from: startDate, to: Date())
    }
    
    private func parseByteCounts(_ string: String) {
        let components = string.components(separatedBy: ",")
        guard components.count == 2 else {
            return
        }
        bytesIn = Int(components[0]) ?? bytesIn
        bytesOut = Int(components[1]) ?? bytesOut
    }
    
    private func needCertificate() throws {
        let certificate = try keychainService.certificate(for: commonNameCertificate)
        let certificateString = certificate.base64EncodedString(options: [.lineLength64Characters])
        let response = "certificate\n-----BEGIN CERTIFICATE-----\n\(certificateString)\n-----END CERTIFICATE-----\nEND\n"
        try write(response)
    }
    
    private func rsaSign(_ stringToSign: String) throws {
        guard let data = Data(base64Encoded: stringToSign, options: [.ignoreUnknownCharacters]) else {
            throw Error.unexpectedError
        }
        let signature = try keychainService.sign(using: commonNameCertificate, dataToSign: data)
        let signatureString = signature.base64EncodedString(options: [.lineLength64Characters])
        let response = "rsa-sig\n\(signatureString)\nEND\n"
        try write(response)
    }

    private func closeManagingSocket() {
        managing = false
        do {
            try write("signal SIGTERM\n")
        } catch {
            debugLog(error)
        }
        socket?.close()
    }
    
    func closeOrphanedConnectionIfNeeded(handler: @escaping (Bool) -> Void) {
        guard FileManager.default.fileExists(atPath: socketPath) else {
            handler(false)
            return
        }
        
        let queue = DispatchQueue.global(qos: .userInteractive)
        queue.async { [unowned self] in
            do {
                let socket = try Socket.create(family: .unix, type: .stream, proto: .unix)
                self.socket = socket
                
                try socket.connect(to: self.socketPath)
                
                try _ = Socket.wait(for: [socket], timeout: 10_000 /* ms */)
                
                self.closeManagingSocket()
            
                // Allow some time to close up
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                   handler(true)
                }
            } catch {
                debugLog(error)
            }
        }
    }
    
}

extension ConnectionService: ClientProtocol {
    
    func taskTerminated(reply: @escaping () -> Void) {
        state = .disconnecting
        reply()
        state = .disconnected
        configURL = nil
        authUserPassURL = nil
    }

}

