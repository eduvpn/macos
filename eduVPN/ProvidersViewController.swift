//
//  ProvidersViewController.swift
//  eduVPN
//
//  Created by Johan Kool on 16/10/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

import Cocoa
import AppAuth
import Reachability

class ProvidersViewController: NSViewController {

    @IBOutlet var tableView: NSTableView!
    @IBOutlet var unreachableLabel: NSTextField!
    @IBOutlet var otherProviderButton: NSButton!
    
    private var providers: [ConnectionType: [Provider]]! {
        didSet {
            var rows: [TableRow] = []
            
            func addRows(connectionType: ConnectionType) {
                if let connectionProviders = providers[connectionType], !connectionProviders.isEmpty {
                    rows.append(.section(connectionType))
                    connectionProviders.forEach { (provider) in
                        rows.append(.provider(provider))
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
        case provider(Provider)
    }
    
    private var rows: [TableRow] = []
    private let reachability = Reachability()
  
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Change title color
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes = [NSAttributedStringKey.font: NSFont.systemFont(ofSize: 17), NSAttributedStringKey.foregroundColor : NSColor.white, NSAttributedStringKey.paragraphStyle : paragraphStyle]
        otherProviderButton.attributedTitle = NSAttributedString(string: otherProviderButton.title, attributes: attributes)
        
        // Handle internet connection state
        reachability?.whenReachable = { [weak self] reachability in
            self?.discoverAccessibleProviders()
            self?.unreachableLabel.isHidden = true
            self?.tableView.isHidden = false
            self?.otherProviderButton.isHidden = false
        }
        
        reachability?.whenUnreachable = { [weak self] _ in
            self?.unreachableLabel.isHidden = false
            self?.tableView.isHidden = true
            self?.otherProviderButton.isHidden = true
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        tableView.deselectAll(nil)
        tableView.isEnabled = true
        
        if !ServiceContainer.providerService.hasAtLeastOneStoredProvider {
            addOtherProvider(animated: false)
        }
        
        discoverAccessibleProviders()
        try? reachability?.startNotifier()
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        reachability?.stopNotifier()
    }
    
    private func discoverAccessibleProviders() {
        ServiceContainer.providerService.discoverAccessibleProviders { (result) in
            DispatchQueue.main.async {
                switch result {
                case .success(let providers):
                    self.providers = providers
                    self.tableView.reloadData()
                case .failure(let error):
                    let alert = NSAlert(error: error)
                    alert.beginSheetModal(for: self.view.window!) { (_) in
                        
                    }
                }
            }
        }
    }
    
    @IBAction func addOtherProvider(_ sender: Any) {
        addOtherProvider(animated: true)
    }
    
    private func addOtherProvider(animated: Bool) {
        #if API_DISCOVERY_DISABLED
        mainWindowController?.showEnterProviderURL(allowClose: !rows.isEmpty, animated: animated, presentation: .present)
        #else
        mainWindowController?.showChooseConnectionType(allowClose: !rows.isEmpty, animated: animated)
        #endif
    }
    
    fileprivate func authenticateAndConnect(to provider: Provider) {
        if let authState = ServiceContainer.authenticationService.authState(for: provider), authState.isAuthorized {
            tableView.isEnabled = false
            ServiceContainer.providerService.fetchInfo(for: provider) { (result) in
                DispatchQueue.main.async {
                    self.tableView.isEnabled = true
                    
                    switch result {
                    case .success(let info):
                        self.fetchProfiles(for: info, authState: authState)
                    case .failure(let error):
                        let alert = NSAlert(error: error)
                        alert.beginSheetModal(for: self.view.window!) { (_) in
                            
                        }
                    }
                }
            }
        } else {
            // No (valid) authentication token
            self.tableView.isEnabled = false
            ServiceContainer.providerService.fetchInfo(for: provider) { (result) in
                DispatchQueue.main.async {
                    self.tableView.isEnabled = true
                    
                    switch result {
                    case .success(let info):
                        self.mainWindowController?.showAuthenticating(with: info, connect: true)
                    case .failure(let error):
                        let alert = NSAlert(error: error)
                        alert.beginSheetModal(for: self.view.window!) { (_) in
                            
                        }
                    }
                }
            }
        }
    }
    
    private func fetchProfiles(for info: ProviderInfo, authState: OIDAuthState) {
        tableView.isEnabled = false
        ServiceContainer.providerService.fetchUserInfoAndProfiles(for: info) { (result) in
            DispatchQueue.main.async {
                self.tableView.isEnabled = true
                
                switch result {
                case .success(let userInfo, let profiles):
                    if profiles.count == 1 {
                        let profile = profiles[0]
                        self.mainWindowController?.showConnection(for: profile, userInfo: userInfo)
                    } else {
                        // Choose profile
                        self.mainWindowController?.showChooseProfile(from: profiles, userInfo: userInfo)
                    }
                case .failure(let error):
                    let alert = NSAlert(error: error)
                    alert.beginSheetModal(for: self.view.window!) { (_) in
                        
                    }
                }
            }
        }
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
        case .provider(let provider):
            let result = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ProfileCell"), owner: self) as? NSTableCellView
            result?.imageView?.kf.setImage(with: provider.logoURL)
            result?.textField?.stringValue = provider.displayName
            return result
        }
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        let tableRow = rows[row]
        switch tableRow {
        case .section:
            return false
        case .provider:
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
        case .provider(let provider):
            authenticateAndConnect(to: provider)
        }
    }
    
}

