//
//  AuthenticatingViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 28/06/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

import Cocoa

class AuthenticatingViewController: NSViewController {

    @IBOutlet var spinner: NSProgressIndicator!

    var info: ProviderInfo!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ServiceContainer.authenticationService.authenticate(using: info) { (result) in
            switch result {
            case .success(let authState):
                ServiceContainer.providerService.fetchProfiles(for: self.info, authState: authState) { (result) in
                    switch result {
                    case .success(let profiles):
                        if profiles.count == 1 {
                            
                        } else {
                            // Choose profile
                        }
                        break
                    case .failure(let error):
                        break
                    }
                }
            case .failure(let error):
                let alert = NSAlert(error: error)
                alert.beginSheetModal(for: self.view.window!) { (_) in
                    
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
    }
}
