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
    var connect: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ServiceContainer.authenticationService.authenticate(using: info) { (result) in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    ServiceContainer.providerService.storeProvider(provider: self.info.provider)
                    if self.connect {
                        self.fetchProfiles(for: self.info)
                    } else {
                        self.mainWindowController?.dismiss()
                    }
                case .failure(let error):
                    // User knows he cancelled, no alert needed
                    if (error as NSError).domain == "org.openid.appauth.general" && (error as NSError).code == -4 {
                        self.mainWindowController?.pop()
                        return
                    }
                    // User knows he rejected, no alert needed
                    if (error as NSError).domain == "org.openid.appauth.oauth_authorization" && (error as NSError).code == -4 {
                        self.mainWindowController?.pop()
                        return
                    }
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
    
    private func fetchProfiles(for info: ProviderInfo) {
        ServiceContainer.providerService.fetchUserInfoAndProfiles(for: info) { (result) in
            DispatchQueue.main.async {
                switch result {
                case .success(let userInfo, let profiles):
                    if profiles.count == 1 {
                        let profile = profiles[0]
                        self.mainWindowController?.showConnection(for: profile, userInfo: userInfo)
                    } else {
                        // Choose profile
                        self.mainWindowController?.showChooseProfile(from: profiles, userInfo: userInfo)
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
}
