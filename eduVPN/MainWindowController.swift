//
//  MainWindowController.swift
//  eduVPN
//
//  Created by Johan Kool on 28/06/2017.
//  Copyright © 2017 eduVPN. All rights reserved.
//

import Cocoa
import AppAuth

/// Does nothing but silence Xcode 9.1 warning
class MainWindow: NSWindow {
    
}

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
    
    // MARK: - Navigation
    
    func push(viewController: NSViewController, animated: Bool = true) {
        navigationStack.append(viewController)
        mainViewController.show(viewController: viewController, options: .slideForward, animated: animated)
    }
    
    func pop(animated: Bool = true) {
        guard navigationStack.count > 1 else {
            return
        }
        navigationStack.removeLast()
        mainViewController.show(viewController: navigationStack.last!, options: .slideBackward, animated: animated)
    }
    
    func popToRoot(animated: Bool = true) {
        guard navigationStack.count > 1 else {
            return
        }
        navigationStack = [navigationStack.first!]
        mainViewController.show(viewController: navigationStack.last!, options: .slideBackward, animated: animated)
    }
    
    func present(viewController: NSViewController, animated: Bool = true) {
        navigationStackStack.append([viewController])
        mainViewController.show(viewController: viewController, options: .slideUp, animated: animated)
    }
    
    func dismiss(animated: Bool = true) {
        guard navigationStackStack.count > 1 else {
            return
        }
        navigationStackStack.removeLast()
        mainViewController.show(viewController: navigationStack.last!, options: .slideDown, animated: animated)
    }
    
    // MARK: - Switching to screens
    
    /// Prompts user to chose a connection type
    ///
    /// - Parameters:
    ///   - allowClose: Wether user may close screen
    ///   - animated: Wether to show with animation
    func showChooseConnectionType(allowClose: Bool, animated: Bool = true) {
        let chooseConnectionTypeViewController = storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "ChooseConnectionType")) as! ChooseConnectionTypeViewController
        chooseConnectionTypeViewController.allowClose = allowClose
        present(viewController: chooseConnectionTypeViewController, animated: animated)
    }

    /// Prompts user to chose a provider
    ///
    /// - Parameters:
    ///   - connectionType: Connection type for the providers
    ///   - providers: Providers to chose from
    ///   - animated: Wether to show with animation
    func showChooseProvider(for connectionType: ConnectionType, from providers: [Provider], animated: Bool = true) {
        let chooseProviderViewController = storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "ChooseProvider")) as! ChooseProviderViewController
        chooseProviderViewController.connectionType = connectionType
        chooseProviderViewController.providers = providers
        push(viewController: chooseProviderViewController, animated: animated)
    }
    
    /// Prompts user to authenticate with provider
    ///
    /// - Parameters:
    ///   - info: Provider to authenticate with
    ///   - profile: Optional profile, if set initiates connection with this profile when authentication succeeds, otherwise fetches profiles and prompts user
    ///   - animated: Wether to show with animation
    func showAuthenticating(with info: ProviderInfo, profile: Profile? = nil, animated: Bool = true) {
        let authenticatingViewController = storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "Authenticating")) as! AuthenticatingViewController
        authenticatingViewController.info = info
        authenticatingViewController.profile = profile
        push(viewController: authenticatingViewController, animated: animated)
    }
    
    /// Prompts user to choose a profile
    ///
    /// - Parameters:
    ///   - profiles: Profiles to chose from
    ///   - authState: Authentication token
    ///   - animated: Wether to show with animation
    func showChooseProfile(from profiles: [Profile], authState: OIDAuthState, animated: Bool = true) {
        let chooseProfileViewController = storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "ChooseProfile")) as! ChooseProfileViewController
        chooseProfileViewController.profiles = profiles
        chooseProfileViewController.authState = authState
        push(viewController: chooseProfileViewController, animated: animated)
    }
    
    /// Shows and starts connection
    ///
    /// - Parameters:
    ///   - profile: Profile
    ///   - authState: Authentication token
    ///   - animated: Wether to show with animation
    func showConnection(for profile: Profile, authState: OIDAuthState, animated: Bool = true) {
        let connectionViewController = storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "Connection")) as! ConnectionViewController
        connectionViewController.profile = profile
        connectionViewController.authState = authState
        push(viewController: connectionViewController, animated: animated)
    }
    
}

extension NSViewController {
    
    var mainWindowController: MainWindowController? {
        return view.window?.windowController as? MainWindowController
    }
    
}
