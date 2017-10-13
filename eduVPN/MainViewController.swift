//
//  MainViewController.swift
//  eduVPN
//
//  Created by Johan Kool on 09/08/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

import Cocoa

class MainViewController: NSViewController {
    
    @IBOutlet var topView: NSView!
    @IBOutlet var containerView: NSView!
    @IBOutlet var menuButton: NSButton!
    @IBOutlet var actionMenu: NSMenu!
    
    @IBAction func showMenu(_ sender: NSControl) {
        actionMenu.popUp(positioning: nil, at: sender.frame.origin, in: sender.superview)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
    }
    
    func show(viewController: NSViewController, options: NSViewController.TransitionOptions = []) {
        let currentViewController = self.currentViewController
        addChildViewController(viewController)
        transition(from: currentViewController, to: viewController, options: options) {
            currentViewController.removeFromParentViewController()
        }
    }
    
    var currentViewController: NSViewController {
        return childViewControllers[0]
    }
    
}
