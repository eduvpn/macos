//
//  AppDelegate.swift
//  EduVPN
//
//  Created by Johan Kool on 28/06/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Setup incoming URL handling
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(AppDelegate.handleAppleEvent(event:with:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func handleAppleEvent(event: NSAppleEventDescriptor, with: NSAppleEventDescriptor) {
        if event.eventClass == AEEventClass(kInternetEventClass),
            event.eventID == AEEventID(kAEGetURL),
            let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue {
            ServiceContainer.connectionService.parseCallback(urlString: urlString)
        }
    }

}

