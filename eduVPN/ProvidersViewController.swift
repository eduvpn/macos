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
                if let connectionProfiles = profiles[connectionType], !connectionProfiles.isEmpty {
                    rows.append(.section(connectionType))
                    connectionProfiles.forEach { (profile) in
                        rows.append(.profile(profile))
                    }
                }
            }
            
            addRows(connectionType: .secureInternet)
            addRows(connectionType: .instituteAccess)
            addRows(connectionType: .custom)
            
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
        
        // Change title color
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes = [NSAttributedStringKey.font: NSFont.systemFont(ofSize: 17), NSAttributedStringKey.foregroundColor : NSColor.white, NSAttributedStringKey.paragraphStyle : paragraphStyle]
        otherProviderButton.attributedTitle = NSAttributedString(string: otherProviderButton.title, attributes: attributes)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
    
        profiles = ServiceContainer.providerService.storedProfiles
        tableView.reloadData()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        tableView.deselectAll(nil)
        tableView.isEnabled = true
        
        if profiles.isEmpty {
            addOtherProvider(animated: false)
        }
    }
    
    @IBAction func addOtherProvider(_ sender: Any) {
        addOtherProvider(animated: true)
    }
    
    private func addOtherProvider(animated: Bool) {
        mainWindowController?.showChooseConnectionType(allowClose: !rows.isEmpty, animated: animated)
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
            result?.imageView?.kf.setImage(with: profile.info.provider.logoURL)
            result?.textField?.stringValue = profile.info.provider.displayName + ": " + profile.displayName
            return result
        }
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        let tableRow = rows[row]
        switch tableRow {
        case .section:
            return false
        case .profile:
            return true
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0 else {
            return
        }
        
        let tableRow = rows[row]
        switch tableRow {
        case .section:
            // Ignore
            break
        case .profile(let profile):
            tableView.isEnabled = false
            if let authState = ServiceContainer.authenticationService.authStates[profile.info.provider.id] {
                mainWindowController?.showConnection(for: profile, authState: authState)
            } else {
                mainWindowController?.showAuthenticating(with: profile.info, profile: profile)
            }
        }
    }
    
}

