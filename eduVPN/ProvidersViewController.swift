//
//  ProvidersViewController.swift
//  eduVPN
//
//  Created by Johan Kool on 16/10/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

import Cocoa

class ProvidersViewController: NSViewController {

    @IBOutlet var tableView: NSTableView!
    @IBOutlet var otherProviderButton: NSButton!
    
    private var profiles: [ConnectionType: [Profile]]! {
        didSet {
            var rows: [TableRow] = []
            
            func addRows(connectionType: ConnectionType) {
                if let connectionProfiles = profiles[.secureInternet], !connectionProfiles.isEmpty {
                    rows.append(.section(.secureInternet))
                    connectionProfiles.forEach { (profile) in
                        rows.append(.profile(profile))
                    }
                }
            }
            
            addRows(connectionType: .secureInternet)
            addRows(connectionType: .instituteAccess)
            
            self.rows = rows
        }
    }
    
    private enum TableRow {
        case section(ConnectionType)
        case profile(Profile)
    }
    
    private var rows: [TableRow] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
 
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
    
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        tableView.deselectAll(nil)
        tableView.isEnabled = true
        
        profiles = ServiceContainer.providerService.storedProfiles
        if profiles.isEmpty {
            addOtherProvider(animated: false)
        }
    }
    
    @IBAction func addOtherProvider(_ sender: Any) {
        addOtherProvider(animated: true)
    }
    
    private func addOtherProvider(animated: Bool) {
        mainWindowController?.showChooseConnectionType(animated: animated, allowClose: !rows.isEmpty)
    }
    
}

extension ProvidersViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return rows.count
    }
    
}

extension ProvidersViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let tableRow = rows[row]
        switch tableRow {
        case .section(let connectionType):
            let result = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "SectionCell"), owner: self) as? NSTableCellView
            result?.textField?.stringValue = connectionType.localizedDescription
            return result
        case .profile(let profile):
            let result = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ProfileCell"), owner: self) as? NSTableCellView
            result?.textField?.stringValue = profile.displayName
            return result
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard tableView.selectedRow >= 0 else {
            return
        }
        
        tableView.isEnabled = false
      //  self.mainWindowController?.showConnection(for: profiles[tableView.selectedRow], authState: authState)
    }
    
}

