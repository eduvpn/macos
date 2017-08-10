//
//  ConnectionViewController.swift
//  eduVPN
//
//  Created by Johan Kool on 28/06/2017.
//  Copyright © 2017 eduVPN. All rights reserved.
//

import Cocoa
import AppAuth

class ConnectionViewController: NSViewController {
    
    @IBOutlet var backButton: NSButton!
    @IBOutlet var stateLabel: NSTextField!
    @IBOutlet var spinner: NSProgressIndicator!
    @IBOutlet var disconnectButton: NSButton!
    @IBOutlet var connectButton: NSButton!
    @IBOutlet var statisticsBox: NSBox!
 
    var profile: Profile!
    var authState: OIDAuthState!
    var statistics: Statistics?
    
    @IBOutlet var statisticsController: NSObjectController!
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
            statisticsBox.isHidden = true
            
        case .connected:
            backButton.isHidden = true
            stateLabel.stringValue = NSLocalizedString("Connected", comment: "")
            spinner.stopAnimation(self)
            disconnectButton.isHidden = false
            connectButton.isHidden = true
            statisticsBox.isHidden = false
            startUpdatingStatistics()
            
        case .disconnecting:
            backButton.isHidden = true
            stateLabel.stringValue = NSLocalizedString("Disonnecting", comment: "")
            spinner.startAnimation(self)
            disconnectButton.isHidden = true
            connectButton.isHidden = true
            statisticsBox.isHidden = true
            stopUpdatingStatistics()
            
        case .disconnected:
            backButton.isHidden = false
            stateLabel.stringValue = NSLocalizedString("Disconnected", comment: "")
            spinner.stopAnimation(self)
            disconnectButton.isHidden = true
            connectButton.isHidden = false
            statisticsBox.isHidden = true

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
    
    private var statisticsTimer: Timer?
    
    private func startUpdatingStatistics() {
        statisticsTimer?.invalidate()
        statisticsTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { (_) in
            self.readStatistics()
        }
    }
    
    private func stopUpdatingStatistics() {
        statisticsTimer?.invalidate()
        statisticsTimer = nil
    }
    
    private func readStatistics() {
        ServiceContainer.connectionService.readStatistics { (result) in
            DispatchQueue.main.async {
                switch result {
                case .success(let statistics):
                    self.statisticsController.content = statistics
                case .failure:
                    self.statisticsController.content = nil
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
