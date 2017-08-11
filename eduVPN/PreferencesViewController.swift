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
        launchAtLoginCheckbox.state = ServiceContainer.preferencesService.launchAtLogin ? NSOnState : NSOffState
    }
    
    @IBAction func toggleLaunchAtLogin(_ sender: NSButton) {
        switch sender.state {
        case NSOnState:
            ServiceContainer.preferencesService.launchAtLogin = true
        case NSOffState:
            ServiceContainer.preferencesService.launchAtLogin = false
        default:
            break
        }
    }
    
}
