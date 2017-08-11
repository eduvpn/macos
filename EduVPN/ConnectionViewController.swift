//
//  ConnectionViewController.swift
//  eduVPN
//
//  Created by Johan Kool on 28/06/2017.
//  Copyright © 2017 eduVPN. All rights reserved.
//

import Cocoa
import AppAuth
import Kingfisher

class ConnectionViewController: NSViewController {
    
    @IBOutlet var backButton: NSButton!
    @IBOutlet var stateImageView: NSImageView!
    @IBOutlet var locationImageView: NSImageView!
    @IBOutlet var profileLabel: NSTextField!
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
        
        // Change title color
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes = [NSFontAttributeName: NSFont.systemFont(ofSize: 17), NSForegroundColorAttributeName : NSColor.white, NSParagraphStyleAttributeName : paragraphStyle]
        connectButton.attributedTitle = NSAttributedString(string: connectButton.title, attributes: attributes)
        disconnectButton.attributedTitle = NSAttributedString(string: disconnectButton.title, attributes: attributes)
        
        locationImageView?.kf.setImage(with: profile.info.provider.logoURL)
        profileLabel.stringValue = profile.displayName
        
        connect()
    }
    
    private func setupForState() {
        switch state {
        case .connecting:
            backButton.isHidden = true
            stateImageView.image = #imageLiteral(resourceName: "connecting")
            (NSApp.delegate as! AppDelegate).statusItem?.image = #imageLiteral(resourceName: "disconnected-1")
            spinner.startAnimation(self)
            disconnectButton.isHidden = true
            connectButton.isHidden = true
            statisticsBox.isHidden = true
            
        case .connected:
            backButton.isHidden = true
            stateImageView.image = #imageLiteral(resourceName: "connected")
            (NSApp.delegate as! AppDelegate).statusItem?.image = #imageLiteral(resourceName: "connected_bw")
            spinner.stopAnimation(self)
            disconnectButton.isHidden = false
            connectButton.isHidden = true
            statisticsBox.isHidden = false
            startUpdatingStatistics()
            
        case .disconnecting:
            backButton.isHidden = true
            stateImageView.image = #imageLiteral(resourceName: "connecting")
            (NSApp.delegate as! AppDelegate).statusItem?.image = #imageLiteral(resourceName: "disconnected-1")
            spinner.startAnimation(self)
            disconnectButton.isHidden = true
            connectButton.isHidden = true
            statisticsBox.isHidden = true
            stopUpdatingStatistics()
            
        case .disconnected:
            backButton.isHidden = false
            stateImageView.image = #imageLiteral(resourceName: "disconnected")
            (NSApp.delegate as! AppDelegate).statusItem?.image = #imageLiteral(resourceName: "disconnected-1")
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
    
    @objc @IBAction func connect(_ sender: Any) {
        connect()
    }
    
    @objc @IBAction func disconnect(_ sender: Any) {
        disconnect()
    }
    
    @IBAction func goBack(_ sender: Any) {
        assert(state == .disconnected)
        mainWindowController?.popToRoot()
    }
    
}
