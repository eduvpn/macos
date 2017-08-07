//
//  MainWindowController.swift
//  eduVPN
//
//  Created by Johan Kool on 28/06/2017.
//  Copyright © 2017 eduVPN. All rights reserved.
//

import Cocoa
import AppAuth

class MainWindowController: NSWindowController {

    private var navigationStack: [NSViewController] = []
    
    override func windowDidLoad() {
        super.windowDidLoad()
    
        navigationStack.append(contentViewController!)
    }
    
    func push(viewController: NSViewController) {
        navigationStack.append(viewController)
        contentViewController = viewController
    }
    
    func pop() {
        guard navigationStack.count > 1 else {
            return
        }
        navigationStack.removeLast()
        contentViewController = navigationStack.last
    }
    
    func popToRoot() {
        guard navigationStack.count > 1 else {
            return
        }
        navigationStack = [navigationStack.first!]
        contentViewController = navigationStack.last
    }
    
    func showChooseConnectType() {
        let chooseConnectionTypeViewController = storyboard!.instantiateController(withIdentifier: "ChooseConnectionType") as! ChooseConnectionTypeViewController
        push(viewController: chooseConnectionTypeViewController)
    }

    func showChooseProvider(for connectionType: ConnectionType, from providers: [Provider]) {
        let chooseProviderViewController = storyboard!.instantiateController(withIdentifier: "ChooseProvider") as! ChooseProviderViewController
        chooseProviderViewController.connectionType = connectionType
        chooseProviderViewController.providers = providers
        push(viewController: chooseProviderViewController)
    }
    
    func showAuthenticating(with info: ProviderInfo) {
        let authenticatingViewController = storyboard!.instantiateController(withIdentifier: "Authenticating") as! AuthenticatingViewController
        authenticatingViewController.info = info
        push(viewController: authenticatingViewController)
    }
    
    func showChooseProfile(from profiles: [Profile], authState: OIDAuthState) {
        let chooseProfileViewController = storyboard!.instantiateController(withIdentifier: "ChooseProfile") as! ChooseProfileViewController
        chooseProfileViewController.profiles = profiles
        chooseProfileViewController.authState = authState
        push(viewController: chooseProfileViewController)
    }
    
    func showConnection(for profile: Profile, authState: OIDAuthState) {
        let connectionViewController = storyboard!.instantiateController(withIdentifier: "Connection") as! ConnectionViewController
        connectionViewController.profile = profile
        connectionViewController.authState = authState
        push(viewController: connectionViewController)
    }
    
}

extension NSViewController {
    
    var mainWindowController: MainWindowController? {
        return view.window?.windowController as? MainWindowController
    }
    
}
