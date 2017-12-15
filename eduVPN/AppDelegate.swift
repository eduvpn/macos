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
        
        if #available(OSX 10.12, *) {
            createStatusItem()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(connectionStateChanged(notification:)), name: ConnectionService.stateChanged, object: ServiceContainer.connectionService)
      
        ServiceContainer.preferencesService.updateForUIPreferences()
        
        ValueTransformer.setValueTransformer(DurationTransformer(), forName: NSValueTransformerName(rawValue: "DurationTransformer"))
        
        mainWindowController = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil).instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "MainWindowController")) as! MainWindowController
        mainWindowController.window?.makeKeyAndOrderFront(nil)
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        switch ServiceContainer.connectionService.state {
        case .disconnected:
            return .terminateNow
        case .connecting, .disconnecting:
            return .terminateCancel
        case .connected:
            ServiceContainer.connectionService.disconnect { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        NSApp.reply(toApplicationShouldTerminate: true)
                    case .failure(let error):
                        NSApp.reply(toApplicationShouldTerminate: false)
                        let alert = NSAlert(error: error)
                        if let window = self.mainWindowController.window {
                            alert.beginSheetModal(for: window) { (_) in
                                
                            }
                        } else {
                            alert.runModal()
                        }
                    }
                }
            }
            return .terminateLater
        }
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
    
    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: 26)
        statusItem?.menu = statusMenu
        updateStatusItemImage()
    }
    
    private func updateStatusItemImage() {
        switch ServiceContainer.connectionService.state {
        case .connecting:
            statusItem?.image = #imageLiteral(resourceName: "disconnected-1")
        case .connected:
            statusItem?.image = #imageLiteral(resourceName: "connected_bw")
        case .disconnecting:
            statusItem?.image = #imageLiteral(resourceName: "disconnected-1")
        case .disconnected:
            statusItem?.image = #imageLiteral(resourceName: "disconnected-1")
        }
    }
    
    var statusItemIsVisible: Bool = false {
        didSet {
            if #available(OSX 10.12, *) {
                statusItem?.isVisible = statusItemIsVisible
            } else {
                // Fallback on earlier versions
                if oldValue != statusItemIsVisible {
                    if statusItemIsVisible {
                        createStatusItem()
                    } else {
                        if let statusItem = statusItem {
                            NSStatusBar.system.removeStatusItem(statusItem)
                        }
                    }
                }
            }
        }
    }
    
    @objc private func connectionStateChanged(notification: NSNotification) {
        DispatchQueue.main.async {
            self.updateStatusItemImage()
        }
    }

}

