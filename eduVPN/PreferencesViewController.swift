//
//  PreferencesViewController.swift
//  eduVPN
//
//  Created by Johan Kool on 10/08/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

import Cocoa

class PreferencesViewController: NSViewController {

    @IBOutlet var launchAtLoginCheckbox: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        launchAtLoginCheckbox.state = ServiceContainer.preferencesService.launchAtLogin ? .on : .off
    }
    
    @IBAction func toggleLaunchAtLogin(_ sender: NSButton) {
        switch sender.state {
        case .on:
            ServiceContainer.preferencesService.launchAtLogin = true
        case .off:
            ServiceContainer.preferencesService.launchAtLogin = false
        default:
            break
        }
    }
    
}
