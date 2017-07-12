//
//  ConnectionViewController.swift
//  EduVPN
//
//  Created by Johan Kool on 28/06/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

import Cocoa
import AppAuth

class ConnectionViewController: NSViewController {
    
    @IBOutlet var backButton: NSButton!
    @IBOutlet var stateLabel: NSTextField!
    @IBOutlet var spinner: NSProgressIndicator!
    @IBOutlet var disconnectButton: NSButton!
    @IBOutlet var connectButton: NSButton!
 
    var profile: Profile!
    var authState: OIDAuthState!

    private enum State {
        case connecting
        case connected
        case disconnecting
        case disconnected
    }
    
    private var state: State = .disconnected {
        didSet {
            setupForState()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        connect()
    }
    
    private func setupForState() {
        switch state {
        case .connecting:
            backButton.isHidden = true
            stateLabel.stringValue = NSLocalizedString("Connecting", comment: "")
            spinner.startAnimation(self)
            disconnectButton.isHidden = true
            connectButton.isHidden = true
            
        case .connected:
            backButton.isHidden = true
            stateLabel.stringValue = NSLocalizedString("Connected", comment: "")
            spinner.stopAnimation(self)
            disconnectButton.isHidden = false
            connectButton.isHidden = true
 
        case .disconnecting:
            backButton.isHidden = true
            stateLabel.stringValue = NSLocalizedString("Disonnecting", comment: "")
            spinner.startAnimation(self)
            disconnectButton.isHidden = true
            connectButton.isHidden = true

        case .disconnected:
            backButton.isHidden = false
            stateLabel.stringValue = NSLocalizedString("Disconnected", comment: "")
            spinner.stopAnimation(self)
            disconnectButton.isHidden = true
            connectButton.isHidden = false

        }
    }
    
    private func connect() {
        assert(state == .disconnected)
        state = .connecting
        ServiceContainer.connectionService.connect(to: profile, authState: authState) { (result) in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.state = .connected
                case .failure(let error):
                    let alert = NSAlert(error: error)
                    alert.beginSheetModal(for: self.view.window!) { (_) in
                        self.state = .disconnected
                    }
                }
            }
        }
    }
    
    private func disconnect() {
        assert(state == .connected)
        state = .disconnecting
        ServiceContainer.connectionService.disconnect() { (result) in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.state = .disconnected
                case .failure(let error):
                    let alert = NSAlert(error: error)
                    alert.beginSheetModal(for: self.view.window!) { (_) in
                        self.state = .connected
                    }
                }
            }
        }
    }
    
    @IBAction func connect(_ sender: Any) {
        connect()
    }
    
    @IBAction func disconnect(_ sender: Any) {
        disconnect()
    }
    
    @IBAction func goBack(_ sender: Any) {
        assert(state == .disconnected)
        mainWindowController?.popToRoot()
    }
    
}
