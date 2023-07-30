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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Make app an accessory if setup is complete (no icon in Dock)
        let isSetupComplete = defaults.bool(forKey: "isSetupComplete")
        if isSetupComplete, let window = NSApplication.shared.windows.first {
            window.close()
            NSApp.setActivationPolicy(.accessory)
        }
        
        // Register for sleep/wake notifications
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(onWakeNotification(notification:)),
            name: NSWorkspace.didWakeNotification, object: nil)

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(onSleepNotification(notification:)),
            name: NSWorkspace.willSleepNotification, object: nil)
    }
    
    @objc func onWakeNotification(notification: NSNotification) {
        wlanModel.evalAutoEnableHotspot()
    }

    @objc func onSleepNotification(notification: NSNotification) {
        print("on sleep")
        
        let isAutoDisconnectWhenSleep = defaults.bool(forKey: "autoDisconnectWhenSleep")
        
        if isAutoDisconnectWhenSleep && bluetoothModel.isDeviceConnected && (bluetoothModel.isConnectedToHotspot || bluetoothModel.isConnectingToHotspot) {
            bluetoothModel.userDisconnectFromHotspot()
        }
    }
}
