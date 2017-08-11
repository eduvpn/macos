//
//  AppDelegate.swift
//  eduVPN
//
//  Created by Johan Kool on 28/06/2017.
//  Copyright © 2017 eduVPN. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var mainWindowController: MainWindowController!
    var statusItem: NSStatusItem?
    @IBOutlet var statusMenu: NSMenu!
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Disabled until best approach to get token is determined
//        // Setup incoming URL handling
//        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(AppDelegate.handleAppleEvent(event:with:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        UserDefaults.standard.register(defaults: NSDictionary(contentsOf: Bundle.main.url(forResource: "Defaults", withExtension: "plist")!)! as! [String : Any])
        
        statusItem = NSStatusBar.system().statusItem(withLength: 26)
        statusItem?.image = #imageLiteral(resourceName: "disconnected-1")
        statusItem?.menu = statusMenu
 
        ServiceContainer.preferencesService.updateForUIPreferences()
        
        mainWindowController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "MainWindowController") as! MainWindowController
        mainWindowController.window?.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func handleAppleEvent(event: NSAppleEventDescriptor, with: NSAppleEventDescriptor) {
        // Disabled until best approach to get token is determined
//        if event.eventClass == AEEventClass(kInternetEventClass),
//            event.eventID == AEEventID(kAEGetURL),
//            let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue {
//            ServiceContainer.connectionService.parseCallback(urlString: urlString)
//        }
    }

    @IBAction func showWindow(_ sender: Any) {
        guard let window = mainWindowController.window else {
            return
        }
        window.setIsVisible(true)
    }
    
}

