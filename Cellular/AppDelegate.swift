//
//  AppDelegate.swift
//  Cellular
//
//  Created by Xuan Han on 24/6/23.
//

import Foundation
import AppKit
import UserNotifications
import CoreLocation

// TODO: Move location stuff to LocationModel, Make BluetoothModel able to be disabled

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, CLLocationManagerDelegate {
    let defaults = UserDefaults.standard
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Make app an accessory if setup is complete (no icon in Dock)
        let isSetupComplete = defaults.bool(forKey: "isSetupComplete")
        if isSetupComplete {
            if let window = NSApplication.shared.windows.first {
                window.close()
                NSApp.setActivationPolicy(.accessory)
            }
        }
        
        // Register for sleep/wake notifications
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(onWakeNotification(notification:)),
            name: NSWorkspace.didWakeNotification, object: nil)
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(onSleepNotification(notification:)),
            name: NSWorkspace.willSleepNotification, object: nil)
        
        // Get local notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if success {
                print("Notification permission granted.")
            } else if let error = error {
                print(error.localizedDescription)
            }
        }
        
        locationModel.registerForAuthorizationChanges {
            if bluetoothModel.isSetupComplete {
                bluetoothModel.initializeBluetooth()
            }
        } onError: {
            if bluetoothModel.isSetupComplete {
                showFailedToStartNotification(reason: .LocationPermissionNotGranted)
            }
            
            // Disconnect device
            
        }

    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return !flag
    }
    
    @objc func onWakeNotification(notification: NSNotification) {
        print("Computer has woken up.")
        
        let isAutoDisconnectWhenSleep = defaults.bool(forKey: "autoDisconnectWhenSleep")
        
        if isAutoDisconnectWhenSleep {
            wlanModel.evalAutoEnableHotspot()
            isSleeping = false
        }
    }
    
    @objc func onSleepNotification(notification: NSNotification) {
        print("Computer is going to sleep.")
        
        let isAutoDisconnectWhenSleep = defaults.bool(forKey: "autoDisconnectWhenSleep")
        
        if isAutoDisconnectWhenSleep {
            if bluetoothModel.isConnectedToHotspot || bluetoothModel.isConnectingToHotspot {
                bluetoothModel.disconnectFromHotspot()
            }
            isSleeping = true
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return !bluetoothModel.isSetupComplete
    }
}
