//
//  AppDelegate.swift
//  Cellular
//
//  Created by Xuan Han on 24/6/23.
//

import Foundation
import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let defaults = UserDefaults.standard
    var statusItem: NSStatusItem!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let isSetupComplete = defaults.bool(forKey: "isSetupComplete")
        if isSetupComplete, let window = NSApplication.shared.windows.first {
            window.close()
            NSApp.setActivationPolicy(.accessory)
        }
        
        // SwiftUI menu bar content view
        let contentView = NSHostingView(rootView: MenuBarContentView())
        contentView.frame = NSRect(x: 0, y: 0, width: 300, height: 400)
        
        // Status bar icon SwiftUI view
        let iconView = NSHostingView(rootView: MenuBarIconView())
        iconView.frame = NSRect(x: 0, y: 0, width: 40, height: 22)
        
        // Creating a menu item and the menu to add them later into the status bar
        let menuItem = NSMenuItem()
        menuItem.view = contentView
        let menu = NSMenu()
        menu.addItem(menuItem)
        
        // Adding content view to the status bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = menu
        
        // Adding the status bar icon
        statusItem.button?.addSubview(iconView)
        statusItem.button?.frame = iconView.frame
        
        print("Added menu bar item")
    }
}
