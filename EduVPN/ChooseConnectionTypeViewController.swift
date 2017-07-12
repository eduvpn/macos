//
//  ChooseConnectionTypeViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 06/07/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

import Cocoa

class ChooseConnectionTypeViewController: NSViewController {

    @IBOutlet var secureInternetButton: NSButton!
    @IBOutlet var instituteAccessButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        secureInternetButton.isEnabled = true
        instituteAccessButton.isEnabled = true
    }
    
    @IBAction func chooseSecureInternet(_ sender: Any) {
        discoverProviders(connectionType: .secureInternet)
    }
   
    @IBAction func chooseInstituteAccess(_ sender: Any) {
        discoverProviders(connectionType: .instituteAccess)
    }
    
    private func discoverProviders(connectionType: ConnectionType) {
        secureInternetButton.isEnabled = false
        instituteAccessButton.isEnabled = false
        ServiceContainer.providerService.discoverProviders(connectionType: connectionType) { result in
            switch result {
            case .success(let providers):
                DispatchQueue.main.async {
                    self.mainWindowController?.showChooseProvider(for: connectionType, from: providers)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    let alert = NSAlert(error: error)
                    alert.beginSheetModal(for: self.view.window!) { (_) in
                        self.secureInternetButton.isEnabled = true
                        self.instituteAccessButton.isEnabled = true
                    }
                }
            }
        }
    }
}
