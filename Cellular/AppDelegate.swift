//
//  AppDelegate.swift
//  Cellular
//
//  Created by Xuan Han on 24/6/23.
//

import Foundation
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let defaults = UserDefaults.standard
    var statusItem: NSStatusItem!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let isSetupComplete = defaults.bool(forKey: "isSetupComplete")
        if isSetupComplete, let window = NSApplication.shared.windows.first {
            window.close()
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
