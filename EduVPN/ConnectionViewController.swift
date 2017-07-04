//
//  ConnectionViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 28/06/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

import Cocoa

class ConnectionViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    @IBAction func disconnect(_ sender: Any) {
        try! ServiceContainer.connectionService.disconnect()
    }
}
