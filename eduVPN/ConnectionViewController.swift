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
    @objc var statistics: Statistics?
    
    @IBOutlet var statisticsController: NSObjectController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Change title color
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes = [NSAttributedStringKey.font: NSFont.systemFont(ofSize: 17), NSAttributedStringKey.foregroundColor : NSColor.white, NSAttributedStringKey.paragraphStyle : paragraphStyle]
        connectButton.attributedTitle = NSAttributedString(string: connectButton.title, attributes: attributes)
        disconnectButton.attributedTitle = NSAttributedString(string: disconnectButton.title, attributes: attributes)
        
        locationImageView?.kf.setImage(with: profile.info.provider.logoURL)
        profileLabel.stringValue = profile.displayName
        
        connect()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        updateForStateChange()
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged(notification:)), name: ConnectionService.stateChanged, object: ServiceContainer.connectionService)
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        NotificationCenter.default.removeObserver(self, name: ConnectionService.stateChanged, object: ServiceContainer.connectionService)
    }
    
    private func updateForStateChange() {
        switch ServiceContainer.connectionService.state {
        case .connecting:
            self.backButton.isHidden = true
            self.stateImageView.image = #imageLiteral(resourceName: "connecting")
            self.spinner.startAnimation(self)
            self.disconnectButton.isHidden = true
            self.connectButton.isHidden = true
            self.statisticsBox.isHidden = false
            
        case .connected:
            self.backButton.isHidden = true
            self.stateImageView.image = #imageLiteral(resourceName: "connected")
            self.spinner.stopAnimation(self)
            self.disconnectButton.isHidden = false
            self.connectButton.isHidden = true
            self.statisticsBox.isHidden = false
            self.startUpdatingStatistics()
            
        case .disconnecting:
            self.backButton.isHidden = true
            self.stateImageView.image = #imageLiteral(resourceName: "connecting")
            self.spinner.startAnimation(self)
            self.disconnectButton.isHidden = true
            self.connectButton.isHidden = true
            self.statisticsBox.isHidden = false
            self.stopUpdatingStatistics()
            
        case .disconnected:
            self.backButton.isHidden = false
            self.stateImageView.image = #imageLiteral(resourceName: "disconnected")
            self.spinner.stopAnimation(self)
            self.disconnectButton.isHidden = true
            self.connectButton.isHidden = false
            self.statisticsBox.isHidden = false
            self.stopUpdatingStatistics()
            
        }
    }
    
    @objc private func stateChanged(notification: NSNotification) {
        DispatchQueue.main.async {
            self.updateForStateChange()
        }
    }
    
    private func connect() {
        statisticsController.content = nil
        ServiceContainer.connectionService.connect(to: profile, authState: authState) { (result) in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    break
                case .failure(let error):
                    let alert = NSAlert(error: error)
                    alert.beginSheetModal(for: self.view.window!) { (_) in
                        self.updateForStateChange()
                    }
                }
            }
        }
    }
    
    private func disconnect() {
        ServiceContainer.connectionService.disconnect() { (result) in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    break
                case .failure(let error):
                    let alert = NSAlert(error: error)
                    alert.beginSheetModal(for: self.view.window!) { (_) in
                        self.updateForStateChange()
                    }
                }
            }
        }
    }
    
    private var statisticsTimer: Timer?
    
    private func startUpdatingStatistics() {
        statisticsTimer?.invalidate()
        if #available(OSX 10.12, *) {
            statisticsTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { (_) in
                self.readStatistics()
            }
        } else {
            // Fallback on earlier versions
            statisticsTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateStatistics(timer:)), userInfo: nil, repeats: true)
        }
    }
    
    @objc private func updateStatistics(timer: Timer) {
        if #available(OSX 10.12, *) {
            fatalError("This method is for backwards compatability only. Remove when deployment target is increased to 10.12 or later.")
        } else {
            // Fallback on earlier versions
            readStatistics()
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
                    break
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
    
    @objc @IBAction func viewLog(_ sender: Any) {
        guard let logURL = ServiceContainer.connectionService.logURL else {
            NSSound.beep()
            return
        }
        NSWorkspace.shared.open(logURL)
    }
    
    @IBAction func goBack(_ sender: Any) {
        assert(ServiceContainer.connectionService.state == .disconnected)
        mainWindowController?.popToRoot()
    }
    
}
