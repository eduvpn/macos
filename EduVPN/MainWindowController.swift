//
//  MainWindowController.swift
//  EduVPN
//
//  Created by Johan Kool on 28/06/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

import Cocoa

class MainWindowController: NSWindowController {

    private var authenticationCancelledObserver: AnyObject?
    private var connectionEstablishedObserver: AnyObject?
    private var connectionTerminatedObserver: AnyObject?
    
    override func windowDidLoad() {
        super.windowDidLoad()
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        
        authenticationCancelledObserver =  NotificationCenter.default.addObserver(forName: AuthenticationService.AuthenticationCancelled, object: ServiceContainer.connectionService, queue: OperationQueue.main) { (_) in
            self.showChooseProvider()
        }
        
        connectionEstablishedObserver =  NotificationCenter.default.addObserver(forName: ConnectionService.ConnectionEstablished, object: ServiceContainer.connectionService, queue: OperationQueue.main) { (_) in
            self.showConnection()
        }
        
        connectionTerminatedObserver =  NotificationCenter.default.addObserver(forName: ConnectionService.ConnectionTerminated, object: ServiceContainer.connectionService, queue: OperationQueue.main) { (_) in
            self.showChooseProvider()
        }
    }
    
    func showChooseConnectType() {
        contentViewController = storyboard?.instantiateController(withIdentifier: "ChooseConnectionType") as? NSViewController
    }

    func showChooseProvider() {
        contentViewController = storyboard?.instantiateController(withIdentifier: "ChooseProvider") as? NSViewController
    }
    
    func showAuthenticating() {
        contentViewController = storyboard?.instantiateController(withIdentifier: "Authenticating") as? NSViewController
    }
    
    func showConnection() {
        contentViewController = storyboard?.instantiateController(withIdentifier: "Connection") as? NSViewController
    }
    
}
