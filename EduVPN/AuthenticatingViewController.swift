//
//  AuthenticatingViewController.swift
//  eduVPN
//
//  Created by Johan Kool on 28/06/2017.
//  Copyright © 2017 eduVPN. All rights reserved.
//

import Cocoa
import AppAuth

class AuthenticatingViewController: NSViewController {

    @IBOutlet var spinner: NSProgressIndicator!
    @IBOutlet var backButton: NSButton!

    var info: ProviderInfo!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ServiceContainer.authenticationService.authenticate(using: info) { (result) in
            DispatchQueue.main.async {
                // TODO: Disable goBack button
                switch result {
                case .success(let authState):
                    self.fetchProfiles(authState: authState)
                case .failure(let error):
                    let alert = NSAlert(error: error)
                    alert.beginSheetModal(for: self.view.window!) { (_) in
                        self.mainWindowController?.pop()
                    }
                }
            }
        }
    }
    
    private func fetchProfiles(authState: OIDAuthState) {
        ServiceContainer.providerService.fetchProfiles(for: self.info, authState: authState) { (result) in
            DispatchQueue.main.async {
                switch result {
                case .success(let profiles):
                    if profiles.count == 1 {
                        self.mainWindowController?.showConnection(for: profiles[0], authState: authState)
                    } else {
                        // Choose profile
                        self.mainWindowController?.showChooseProfile(from: profiles, authState: authState)
                    }
                case .failure(let error):
                    let alert = NSAlert(error: error)
                    alert.beginSheetModal(for: self.view.window!) { (_) in
                        self.mainWindowController?.pop()
                    }
                }
            }
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        spinner.startAnimation(nil)
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        spinner.stopAnimation(nil)
    }
    
    @IBAction func goBack(_ sender: Any) {
        ServiceContainer.authenticationService.cancelAuthentication()
        // Already triggerd? mainWindowController?.pop()
    }
    
}
