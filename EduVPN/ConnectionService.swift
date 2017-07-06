//
//  ConnectionService.swift
//  EduVPN
//
//  Created by Johan Kool on 30/06/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

import Foundation
import AppKit
import ServiceManagement
import AppAuth

class ConnectionService: NSObject {
    

    
    static let AuthenticationInitiated: NSNotification.Name = NSNotification.Name("ConnectionService.AuthenticationInitiated")
    static let AuthenticationCancelled: NSNotification.Name = NSNotification.Name("ConnectionService.AuthenticationCancelled")
    static let AuthenticationSucceeded: NSNotification.Name = NSNotification.Name("ConnectionService.AuthenticationSucceeded")
    static let ConnectionEstablished: NSNotification.Name = NSNotification.Name("ConnectionService.ConnectionEstablished")
    static let ConnectionTerminated: NSNotification.Name = NSNotification.Name("ConnectionService.ConnectionTerminated")

    override init() {
        super.init()
        discoverProviders()
//        let error = ConnectionError.installationFailed
//        let alert = NSAlert(error: error)
//        alert.addButton(withTitle: "Quit")
//        alert.runModal()
//        exit(0)
//        connectToAuthorization()
        installHelperIfNeeded()
    }
    
    private var expectedState: String?
    
    func discoverProviders() {
        providers = [Provider(displayName: "EduVPN", baseURL: URL(string: "https://demo.eduvpn.nl/")!, logoURL: URL(string: "https://static.eduvpn.nl/img/demo.png")!)]
    }
    
    private(set) var providers: [Provider] = []
    
    func connectTo(provider: Provider) throws {
        // TODO: Fetch provider info (from cache)
        let providerInfo = ProviderInfo(apiBaseURL: URL(string: "https://demo.eduvpn.nl/portal/api.php")!, authorizationURL: URL(string: "https://demo.eduvpn.nl/portal/_oauth/authorize")!, tokenURL: URL(string: "https://demo.eduvpn.nl/portal/oauth.php/token")!)
        try authenticate(using: providerInfo)
    }
    
    private var redirectHTTPHandler: OIDRedirectHTTPHandler?
    private var authState: OIDAuthState?
    
    private func authenticate(using info: ProviderInfo) throws {
        guard var components = URLComponents(url: info.authorizationURL, resolvingAgainstBaseURL: true) else {
            throw ConnectionError.invalidProviderInfo
        }
        
        
        let configuration = OIDServiceConfiguration(authorizationEndpoint: info.authorizationURL, tokenEndpoint: info.tokenURL)
        
        redirectHTTPHandler = OIDRedirectHTTPHandler(successURL: nil) // URL(string: "org.eduvpn.app:/api/callback")!)
        let redirectURL = URL(string: "callback", relativeTo: redirectHTTPHandler!.startHTTPListener(nil))!
        let request = OIDAuthorizationRequest(configuration: configuration, clientId: "org.eduvpn.app", clientSecret: nil, scopes: ["config"], redirectURL: redirectURL, responseType: OIDResponseTypeCode, additionalParameters: nil)
        
        
        // performs authentication request
      //  __weak __typeof(self) weakSelf = self;
        redirectHTTPHandler!.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request) { (authState, error) in
            NSRunningApplication.current().activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            
            self.authState = authState
      
            if let authState = authState {
                NSLog("Got authorization tokens. Access token: \(authState.lastTokenResponse?.accessToken)")
                NotificationCenter.default.post(name: ConnectionService.AuthenticationSucceeded, object: self)
                
                self.authenticationSucceeded()
            } else if let error = error {
                NSLog("Authorization error: \(error.localizedDescription)")
            }
         }
        
        NotificationCenter.default.post(name: ConnectionService.AuthenticationInitiated, object: self)
        
//        redirectHTTPHandler.currentAuthorizationFlow =
//            [OIDAuthState authStateByPresentingAuthorizationRequest:request
//                callback:^(OIDAuthState *_Nullable authState,
//                NSError *_Nullable error) {
//                // Brings this app to the foreground.
//                [[NSRunningApplication currentApplication]
//                activateWithOptions:(NSApplicationActivateAllWindows |
//                NSApplicationActivateIgnoringOtherApps)];
//                
//                // Processes the authorization response.
//                if (authState) {
//                NSLog(@"Got authorization tokens. Access token: %@",
//                authState.lastTokenResponse.accessToken);
//                } else {
//                NSLog(@"Authorization error: %@", error.localizedDescription);
//                }
//                [weakSelf setAuthState:authState];
//                }];
//        
//        expectedState = "3983d01b-b6c0-44f3-8034-2c1f70451ac9" // TODO: Generate random string
//        
//        // codeVerifier = [OIDTokenUtilities randomURLSafeStringWithSize:kCodeVerifierBytes];
//        
////        // generates the code_challenge per spec https://tools.ietf.org/html/rfc7636#section-4.2
////        // code_challenge = BASE64URL-ENCODE(SHA256(ASCII(code_verifier)))
////        // NB. the ASCII conversion on the code_verifier entropy was done at time of generation.
////        NSData *sha256Verifier = [OIDTokenUtilities sha265:codeVerifier];
////        return [OIDTokenUtilities encodeBase64urlNoPadding:sha256Verifier];
//        
//        let queryItems = [URLQueryItem(name: "client_id", value: "org.eduvpn.app"),
//                          URLQueryItem(name: "redirect_uri", value: "org.eduvpn.app:/api/callback"),
//                          URLQueryItem(name: "response_type", value: "code"),
//                          URLQueryItem(name: "code_challenge_method", value: "S256"),
//                          URLQueryItem(name: "scope", value: "config"),
//                          URLQueryItem(name: "state", value: expectedState!)]
//        components.queryItems = queryItems
//        
//        guard let url = components.url else {
//            throw ConnectionError.invalidProviderInfo
//        }
//    
//        try NSWorkspace.shared().open(url, options: [.withErrorPresentation, .inhibitingBackgroundOnly], configuration: [:])
//        
//        NotificationCenter.default.post(name: ConnectionService.AuthenticationInitiated, object: self)
    }
    
    func cancelAuthentication() {
        guard expectedState != nil else {
            return
        }
        
        expectedState = nil
        NotificationCenter.default.post(name: ConnectionService.AuthenticationCancelled, object: self)
    }
    
//    func parseCallback(urlString: String) {
//        do {
//            // TODO: Handle: "nl.eduvpn.app://import/callback#error=access_denied&state=3983d01b-b6c0-44f3-8034-2c1f70451ac9"
//
//            
//            let token = try parseToken(urlString: urlString)
//            try verifyToken(token: token)
//            
    
    func authenticationSucceeded() {
        do {
            let providerInfo = ProviderInfo(apiBaseURL: URL(string: "https://demo.eduvpn.nl/portal/api.php" + "/")!, authorizationURL: URL(string: "https://demo.eduvpn.nl/portal/_oauth/authorize")!, tokenURL: URL(string: "https://demo.eduvpn.nl/portal/oauth.php/token")!)
            try createKeyPair(using: providerInfo) { (result) in
                switch result {
                case .success((let certificate, let privateKey)):
                    try? self.fetchProfile(using: providerInfo) { (result) in
                        switch result {
                        case .success(let config):
                            let profileConfig = self.consolidate(config: config, certificate: certificate, privateKey: privateKey)
                            let profileURL = try! self.install(config: profileConfig)
                            self.activateConfig(at: profileURL)
                            break
                        case .failure(let error):
                            break
                        }
                    }
                    break
                case .failure(let error):
                    
                    break
                }
            }
            NotificationCenter.default.post(name: ConnectionService.AuthenticationSucceeded, object: self)
        } catch (let error) {
            NSLog("callback error \(error)")
        }
    }
//
//    private func parseToken(urlString: String) throws -> Token {
//        guard urlString.hasPrefix("org.eduvpn.app://import/callback") else {
//            throw ConnectionError.invalidURL
//        }
//        
//        // Returned as fragment, but easier to parse as query
//        let urlString = urlString.replacingOccurrences(of: "org.eduvpn.app://import/callback#", with: "org.eduvpn.app://import/callback?")
//        
//        guard let comps = URLComponents(string: urlString) else {
//            throw ConnectionError.invalidURL
//        }
//        
//        guard let items = comps.queryItems else {
//            throw ConnectionError.invalidURL
//        }
//        
//        guard let accessToken = items.first(where: { $0.name == "access_token" })?.value else {
//            throw ConnectionError.invalidURL
//        }
//
//        guard let tokenTypeString = items.first(where: { $0.name == "token_type" })?.value,
//            let tokenType = Token.TokenType(rawValue: tokenTypeString) else {
//            throw ConnectionError.invalidURL
//        }
//
//        guard let expiresIn = items.first(where: { $0.name == "expires_in" })?.value,
//            let expiresInt = TimeInterval(expiresIn) else {
//            throw ConnectionError.invalidURL
//        }
//
//        let expiresOn = Date(timeIntervalSinceNow: expiresInt)
//        
//        guard let state = items.first(where: { $0.name == "state" })?.value else {
//            throw ConnectionError.invalidURL
//        }
//
//        return Token(accessToken: accessToken, type: tokenType, expiresOn: expiresOn, state: state)
//    }
//    
//    private func verifyToken(token: Token) throws {
//        guard let expectedState = expectedState else {
//            throw ConnectionError.unexpectedState
//        }
//        
//        guard expectedState == token.state else {
//            throw ConnectionError.unexpectedState
//        }
//    }
    
    
    
    private func createKeyPair(using info: ProviderInfo, handler: @escaping (Either<(certificate: String, privateKey: String)>) -> ()) throws {
        guard let url = URL(string: "create_keypair", relativeTo: info.apiBaseURL) else {
            throw ConnectionError.invalidURL
        }
        
        authState?.performAction() { (accessToken, idToken, error) in
            guard let accessToken = accessToken else {
                fatalError()
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            let data = "display_name=test".data(using: .utf8)!
            request.httpBody = data
            request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
            
            let task = URLSession.shared.dataTask(with: request) { (data, _, error) in
                guard let data = data else {
                    handler(.failure(error ?? ConnectionError.unknown))
                    return
                }
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary else {
                        handler(.failure(ConnectionError.invalidKeyPair))
                        return
                    }
                    
                    guard let certificate = json.value(forKeyPath: "create_keypair.data.certificate") as? String else {
                        handler(.failure(ConnectionError.invalidKeyPair))
                        return
                    }
                    
                    guard let privateKey = json.value(forKeyPath: "create_keypair.data.private_key") as? String else {
                        handler(.failure(ConnectionError.invalidKeyPair))
                        return
                    }
                    
                    handler(.success((certificate: certificate, privateKey: privateKey)))
                } catch(let error) {
                    handler(.failure(error))
                    return
                }
            }
            task.resume()

        }
        
    }
    
    
    private func fetchProfile(using info: ProviderInfo, id: String = "internet", handler: @escaping (Either<String>) -> ()) throws {
        guard let url = URL(string: "profile_config?profile_id=\(id)", relativeTo: info.apiBaseURL) else {
            throw ConnectionError.invalidURL
        }
        
        authState?.performAction() { (accessToken, idToken, error) in
            guard let accessToken = accessToken else {
                fatalError()
            }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { (data, _, error) in
            guard let data = data else {
                handler(.failure(error ?? ConnectionError.unknown))
                return
            }
            
            guard let config = String(data: data, encoding: .utf8) else {
                handler(.failure(ConnectionError.invalidConfiguration))
                return
            }
            
            handler(.success(config))
        }
        task.resume()
        }
    }
    
    private func consolidate(config: String, certificate: String, privateKey: String) -> String {
        return config + "\n<cert>\n" + certificate + "\n</cert>\n<key>\n" + privateKey + "\n</key>"
    }
    
    private func install(config: String) throws -> URL {
        let tempDir = NSTemporaryDirectory()
        let fileURL = URL(fileURLWithPath: tempDir + "/eduvpn.ovpn")
        try config.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    private var connection: NSXPCConnection?
    
    private var authRef: AuthorizationRef? = nil
    private var authorization: Data!
    
//    private func connectToAuthorization() {
//        var authRef: AuthorizationRef?
//        var err = AuthorizationCreate(nil, nil, [], &authRef)
//        self.authRef = authRef
//       
//        var form = AuthorizationExternalForm()
//        
//        if (err == errAuthorizationSuccess) {
//            err = AuthorizationMakeExternalForm(authRef!, &form);
//        }
//        if (err == errAuthorizationSuccess) {
//            self.authorization = Data(bytes: &form.bytes, count: MemoryLayout.size(ofValue: form.bytes))
//        }
//    }
    
    private func installHelperIfNeeded() {
        connectToHelper { upToDate in
            if upToDate {
                // Connected and up-to-date
            } else {
                // Not installed or not up-to-date
                do {
                    try self.installHelper()
                } catch (let error) {
                    // Installation failed
                    let alert = NSAlert(error: error)
                    alert.runModal()
                }
                // Installation succeeded, try again
                self.connectToHelper { upToDate in
                    if upToDate {
                        // Connected and up-to-date
                    } else {
                        // Something went haywhire
                        let alert = NSAlert(error: ConnectionError.installationFailed)
                        alert.runModal()
                    }
                }
            }
        }
    }
    
    private func installHelper() throws {
        var status = AuthorizationCreate(nil, nil, AuthorizationFlags(), &authRef)
        if (status != OSStatus(errAuthorizationSuccess)) {
            print("AuthorizationCreate failed.")
            throw ConnectionError.authenticationFailed
        }
        
        var item = AuthorizationItem(name: kSMRightBlessPrivilegedHelper, valueLength: 0, value: nil, flags: 0)
        var rights = AuthorizationRights(count: 1, items: &item)
        let flags = AuthorizationFlags([.interactionAllowed, .extendRights])
        
        status = AuthorizationCopyRights(authRef!, &rights, nil, flags, nil)
        if (status != errAuthorizationSuccess) {
            print("AuthorizationCopyRights failed.")
            throw ConnectionError.authenticationFailed
        }

        var error: Unmanaged<CFError>?
        let success = SMJobBless(
            kSMDomainSystemLaunchd,
            ConnectionService.helperIdentifier as CFString,
            authRef,
            &error
        );
        
        if (success) {
            NSLog("job blessed")
        } else {
            NSLog("job NOT blessed \(String(describing: error))")
            throw ConnectionError.installationFailed
        }
    }
    
    private func connectToHelper(_ callback: @escaping (Bool) -> ()) {
            connection = NSXPCConnection(machServiceName: ConnectionService.helperIdentifier, options: .privileged)
            connection?.remoteObjectInterface = NSXPCInterface(with: OpenVPNHelperProtocol.self)
            connection?.exportedInterface = NSXPCInterface(with: ClientProtocol.self)
            connection?.exportedObject = self
            connection?.invalidationHandler = { _ in
                NSLog("connection invalidated!")
            }
            connection?.interruptionHandler = { _ in
                NSLog("connection interrupted!")
            }
            connection?.resume()
        
        do {
            try getHelperVersion { (version) in
                callback(version == ConnectionService.helperVersion)
            }
        } catch {
            callback(false)
        }
    }
    
    private func getHelperVersion(_ callback: @escaping (String) -> ()) throws {
        guard let helper = connection?.remoteObjectProxyWithErrorHandler({ error in
            NSLog("connection error: \(error)")
            callback("")
        }) as? OpenVPNHelperProtocol else {
            throw ConnectionError.noHelperConnection
        }
        
        helper.getVersionWithReply() { (version) in
            callback(version ?? "")
        }
    }
    
    static let openVPNSubdirectory = "openvpn-2.4.3-openssl-1.0.2k"
    static let helperVersion = "1.0-1"
    static let helperIdentifier = "org.eduvpn.app.openvpnhelper"
    
    private func activateConfig(at configURL: URL) {
        
        if let helper = connection?.remoteObjectProxyWithErrorHandler({ (error) in
            NSLog("connection error: \(error)")
        }) as? OpenVPNHelperProtocol {
            helper.getVersionWithReply() { (version) in
                NSLog("helper version: \(version)")
            }
            
            let bundle = Bundle.init(for: ConnectionService.self)
            
            let openvpnURL = bundle.url(forResource: "openvpn", withExtension: nil, subdirectory: ConnectionService.openVPNSubdirectory)!
            
            helper.startOpenVPN(at: openvpnURL, withConfig: configURL) { (message) in
                 NSLog("did connect?: \(message)")
                NotificationCenter.default.post(name: ConnectionService.ConnectionEstablished, object: self)
            }
        }
        
    }
    
    func disconnect() throws {
        guard let helper = connection?.remoteObjectProxy as? OpenVPNHelperProtocol else {
            throw ConnectionError.noHelperConnection
        }
        
        helper.close { (message) in
            NSLog("did disconnect?: \(message)")
            NotificationCenter.default.post(name: ConnectionService.ConnectionTerminated, object: self)
        }
    }
    
}

enum ConnectionError: Int, Error, LocalizedError {
    case invalidProviderInfo
    case invalidURL
    case unexpectedState
    case invalidKeyPair
    case invalidConfiguration
    case noHelperConnection
    case authenticationFailed
    case installationFailed
    case unknown
    
//    var errorDescription: String? {
//        switch self {
//        case .installationFailed:
//            return NSLocalizedString("Installation failed", comment: "")
//        default:
//            return NSLocalizedString("Connection error \(self)", comment: "")
//        }
//    }
    
    var failureReason: String? {
        switch self {
        case .installationFailed:
            return NSLocalizedString("jfljsdlkf", comment: "")
        default:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .installationFailed:
            return NSLocalizedString("Try reinstalling EduVPN.", comment: "")
        default:
            return nil
        }
    }
}

extension ConnectionService: ClientProtocol {
    
    func stateChanged(_ state: OpenVPNState, reply: (() -> Void)!) {
        NSLog("state \(state)")
    }
}
