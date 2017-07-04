//
//  ChooseProviderViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 28/06/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

import Cocoa

class ChooseProviderViewController: NSViewController {

    @IBOutlet var tableView: NSTableView!
    fileprivate var providers: [Provider] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        providers = ServiceContainer.connectionService.providers
        tableView.reloadData()
    }
    
}

extension ChooseProviderViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return providers.count
    }
    
}

extension ChooseProviderViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, willDisplayCell cell: Any, for tableColumn: NSTableColumn?, row: Int) {
        (cell as! NSTableCellView).textField?.stringValue = providers[row].displayName
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        (view.window?.windowController as? MainWindowController)?.showAuthenticating()
        do {
            try ServiceContainer.connectionService.connectTo(provider: providers[tableView.selectedRow])
        } catch(let error) {
            NSAlert(error: error).beginSheetModal(for: view.window!, completionHandler: nil)
        }
    }
    
}
