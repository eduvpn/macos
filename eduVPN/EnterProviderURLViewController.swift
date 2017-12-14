//
//  EnterProviderURLViewController.swift
//  eduVPN
//
//  Created by Johan Kool on 03/11/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

import Cocoa

class EnterProviderURLViewController: NSViewController {

    enum Error: Swift.Error, LocalizedError {
        case invalidURL
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return NSLocalizedString("URL is invalid", comment: "")
            }
        }
        
        var recoverySuggestion: String? {
            return NSLocalizedString("Enter a valid URL.", comment: "")
        }
    }
    
    @IBOutlet var textField: NSTextField!
    @IBOutlet var backButton: NSButton!
    @IBOutlet var doneButton: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Change title color
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes = [NSAttributedStringKey.font: NSFont.systemFont(ofSize: 17), NSAttributedStringKey.foregroundColor : NSColor.white, NSAttributedStringKey.paragraphStyle : paragraphStyle]
        doneButton.attributedTitle = NSAttributedString(string: doneButton.title, attributes: attributes)
    }
    
    @IBAction func goBack(_ sender: Any) {
        mainWindowController?.pop()
    }
    
    private func validURL() -> URL? {
        let string = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: string), let scheme = url.scheme, ["http", "https"].contains(scheme), let _ = url.host {
            return url
        } else {
            return nil
        }
    }
    
    @IBAction func done(_ sender: Any) {
        textField.resignFirstResponder()
        textField.isEnabled = false
        doneButton.isEnabled = false
        
        guard let url = validURL(), let host = url.host else {
            let alert = NSAlert(error: Error.invalidURL)
            alert.beginSheetModal(for: self.view.window!) { (_) in
                self.textField.isEnabled = true
            }
            return
        }
        
        let provider = Provider(displayName: host, baseURL: url, logoURL: nil, publicKey: nil, connectionType: .custom, authorizationType: .local)
        ServiceContainer.providerService.fetchInfo(for: provider) { result in
            switch result {
            case .success(let info):
                DispatchQueue.main.async {
                    self.textField.isEnabled = true
                    self.doneButton.isEnabled = true
                    self.mainWindowController?.showAuthenticating(with: info)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    let alert = NSAlert(error: error)
                    alert.beginSheetModal(for: self.view.window!) { (_) in
                        self.textField.isEnabled = true
                        self.doneButton.isEnabled = true
                    }
                }
            }
        }
    }
    
}

extension EnterProviderURLViewController: NSTextFieldDelegate {
    
    override func controlTextDidChange(_ obj: Notification) {
        doneButton.isEnabled = validURL() != nil
    }
    
}
