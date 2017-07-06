//
//  ChooseProviderViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 28/06/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

import Cocoa
import Kingfisher

class ChooseProviderViewController: NSViewController {

    @IBOutlet var tableView: NSTableView!
    
    var connectionType: ConnectionType!
    var providers: [Provider]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    @IBAction func goBack(_ sender: Any) {
        mainWindowController?.showChooseConnectType()
    }
    
}

extension ChooseProviderViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return providers.count
    }
    
}

extension ChooseProviderViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let result = tableView.make(withIdentifier: "ProviderCell", owner: self) as? NSTableCellView
        result?.imageView?.kf.setImage(with: providers[row].logoURL)
        result?.textField?.stringValue = providers[row].displayName
        return result
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        tableView.isEnabled = false
        ServiceContainer.providerService.fetchInfo(for: providers[tableView.selectedRow]) { result in
            switch result {
            case .success(let info):
                DispatchQueue.main.async {
                    self.mainWindowController?.showAuthenticating(with: info)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    let alert = NSAlert(error: error)
                    alert.beginSheetModal(for: self.view.window!) { (_) in
                        self.tableView.isEnabled = true
                    }
                }
            }
        }
    }
    
}
