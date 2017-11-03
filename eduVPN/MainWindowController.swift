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

    private var navigationStackStack: [[NSViewController]] = [[]]
    private var navigationStack: [NSViewController] {
        get {
            return navigationStackStack.last!
        }
        set {
            navigationStackStack.removeLast()
            navigationStackStack.append(newValue)
        }
    }
    @IBOutlet var topView: NSBox!
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        window?.backgroundColor = .white
        // Disabled, clips
//        window?.titlebarAppearsTransparent = true
//        topView.frame = CGRect(x: 0, y: 539, width: 378, height: 60)
//        window?.contentView?.addSubview(topView)

        navigationStack.append(mainViewController.currentViewController)
    }
    
    private var mainViewController: MainViewController {
        return contentViewController as! MainViewController
    }
    
    func push(viewController: NSViewController) {
        navigationStack.append(viewController)
        mainViewController.show(viewController: viewController, options: .slideForward)
    }
    
    func pop() {
        guard navigationStack.count > 1 else {
            return
        }
        navigationStack.removeLast()
        mainViewController.show(viewController: navigationStack.last!, options: .slideBackward)
    }
    
    func popToRoot() {
        guard navigationStack.count > 1 else {
            return
        }
        navigationStack = [navigationStack.first!]
        mainViewController.show(viewController: navigationStack.last!, options: .slideBackward)
    }
    
    func present(viewController: NSViewController, animated: Bool = true) {
        navigationStackStack.append([viewController])
        mainViewController.show(viewController: viewController, options: .slideUp)
    }
    
    func dismiss() {
        guard navigationStackStack.count > 1 else {
            return
        }
        navigationStackStack.removeLast()
        mainViewController.show(viewController: navigationStack.last!, options: .slideDown)
    }
    
    func showChooseConnectionType(animated: Bool, allowClose: Bool) {
        let chooseConnectionTypeViewController = storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "ChooseConnectionType")) as! ChooseConnectionTypeViewController
        present(viewController: chooseConnectionTypeViewController, animated: animated)
    }

    func showChooseProvider(for connectionType: ConnectionType, from providers: [Provider]) {
        let chooseProviderViewController = storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "ChooseProvider")) as! ChooseProviderViewController
        chooseProviderViewController.connectionType = connectionType
        chooseProviderViewController.providers = providers
        push(viewController: chooseProviderViewController)
    }
    
    func showAuthenticating(with info: ProviderInfo) {
        let authenticatingViewController = storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "Authenticating")) as! AuthenticatingViewController
        authenticatingViewController.info = info
        push(viewController: authenticatingViewController)
    }
    
    func showChooseProfile(from profiles: [Profile], authState: OIDAuthState) {
        let chooseProfileViewController = storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "ChooseProfile")) as! ChooseProfileViewController
        chooseProfileViewController.profiles = profiles
        chooseProfileViewController.authState = authState
        push(viewController: chooseProfileViewController)
    }
    
    func showConnection(for profile: Profile, authState: OIDAuthState) {
        let connectionViewController = storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "Connection")) as! ConnectionViewController
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
