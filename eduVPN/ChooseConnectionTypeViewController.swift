//
//  ChooseConnectionTypeViewController.swift
//  eduVPN
//
//  Created by Johan Kool on 06/07/2017.
//  Copyright © 2017 eduVPN. All rights reserved.
//

import Cocoa

class ChooseConnectionTypeViewController: NSViewController {

    @IBOutlet var secureInternetButton: NSButton!
    @IBOutlet var instituteAccessButton: NSButton!
    @IBOutlet var closeButton: NSButton!
    @IBOutlet var enterProviderButton: NSButton!
    @IBOutlet var chooseConfigFileButton: NSButton!
    
    var allowClose: Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        view.layer?.backgroundColor = NSColor.white.cgColor
        closeButton.isHidden = !allowClose
        
        // Change title color
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes = [NSAttributedStringKey.font: NSFont.systemFont(ofSize: 17), NSAttributedStringKey.foregroundColor : NSColor.white, NSAttributedStringKey.paragraphStyle : paragraphStyle]
        enterProviderButton.attributedTitle = NSAttributedString(string: enterProviderButton.title, attributes: attributes)
        chooseConfigFileButton.attributedTitle = NSAttributedString(string: chooseConfigFileButton.title, attributes: attributes)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        secureInternetButton.isEnabled = true
        instituteAccessButton.isEnabled = true
    }
    
    @IBAction func chooseSecureInternet(_ sender: Any) {
        discoverProviders(connectionType: .secureInternet)
    }
   
    @IBAction func chooseInstituteAccess(_ sender: Any) {
        discoverProviders(connectionType: .instituteAccess)
    }
    
    @IBAction func close(_ sender: Any) {
        mainWindowController?.dismiss()
    }
    
    @IBAction func enterProviderURL(_ sender: Any) {
        mainWindowController?.showEnterProviderURL()
    }
    
    @IBAction func chooseConfigFile(_ sender: Any) {
        guard let window = view.window else {
            return
        }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedFileTypes = ["ovpn"]
        panel.beginSheetModal(for: window) { (response) in
            switch response {
            case .OK:
                if let url = panel.urls.first {
                    ServiceContainer.providerService.addProvider(configFileURL: url)
                    self.mainWindowController?.dismiss()
                }
            default:
                break
            }
        }
    }
    
    private func discoverProviders(connectionType: ConnectionType) {
        secureInternetButton.isEnabled = false
        instituteAccessButton.isEnabled = false
        ServiceContainer.providerService.discoverProviders(connectionType: connectionType) { result in
            switch result {
            case .success(let providers):
                DispatchQueue.main.async {
                    self.mainWindowController?.showChooseProvider(for: connectionType, from: providers)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    let alert = NSAlert(error: error)
                    alert.beginSheetModal(for: self.view.window!) { (_) in
                        self.secureInternetButton.isEnabled = true
                        self.instituteAccessButton.isEnabled = true
                    }
                }
            }
        }
    }
}
