//
//  WLANModel.swift
//  Cellular
//
//  Created by Xuan Han on 23/7/23.
//

import Foundation
import CoreWLAN

func syncMain<T>(_ closure: () -> T) -> T {
    if Thread.isMainThread {
        return closure()
    } else {
        return DispatchQueue.main.sync(execute: closure)
    }
}

/**
 This class handles all things related to Wi-Fi.
 */
class WLANModel: NSObject, ObservableObject, CWEventDelegate {
    private let defaults = UserDefaults.standard
    private let cwWiFiClient = CWWiFiClient.shared()
    private let cwInterface: CWInterface!
    private var connectDispatchTask: DispatchWorkItem? // IMPT: Must not be set to nil or else connect() won't be able to check if task has been cancelled!
    var ssid: String?
    private var password: String?
    private var connectHotspotRetryCount = 0
    private var connectionTimer: Timer?
    private var userRecentlyConnectedWhileOnTrustedNetwork = false
    var userRecentlyDisconnectedFromHotspot = false
    
    override init() {
        cwInterface = cwWiFiClient.interface()!
        super.init()
        cwWiFiClient.delegate = self
        
        do {
            try cwWiFiClient.startMonitoringEvent(with: .linkDidChange)
            try cwWiFiClient.startMonitoringEvent(with: .scanCacheUpdated)
        } catch {
            print("Failed to start Wi-Fi monitoring: \(error.localizedDescription)")
        }
    }
    
    /**
     This function sets the hotspot details for later use.
     - parameter ssid: The SSID of the hotspot
     - parameter password: The password of the hotspot
     */
    func setHotspotDetails(ssid: String, password: String) {
        self.ssid = ssid
        self.password = password
    }
    
    /**
     This function connects to the hotspot.
     - parameter completionHandler: The function to call when connection is successful
     - parameter onError: The function to call when connection is unsuccessful
     */
    func connect(completionHandler: @escaping () -> Void, onError: @escaping () -> Void) {
        guard ssid != nil else {
            print("Hotspot SSID must be set before calling this function.")
            return
        }
        guard password != nil else {
            print("Hotspot password must be set before calling this function.")
            return
        }
        
        connectDispatchTask = DispatchWorkItem { [self] in
            do {
                // Check if user is currently connected to a trusted network
                if let currentSSID = cwInterface.ssid() {
                    let trustedNetworkSSIDs = defaults.stringArray(forKey: "trustedNetworks") ?? []
                    if trustedNetworkSSIDs.contains(currentSSID) {
                        userRecentlyConnectedWhileOnTrustedNetwork = true
                    }
                }
                
                // Scan for hotspot
                var selNetwork: CWNetwork? = nil
                for network in try cwInterface.scanForNetworks(withName: ssid) {
                    if network.ssid == ssid {
                        selNetwork = network
                    }
                }
                
                if selNetwork != nil {
                    // Attempt to connect to hotspot if it is found
                    try cwInterface.associate(to: selNetwork!, password: password)
                    
                    DispatchQueue.main.sync {
                        connectHotspotRetryCount = 0
                        connectDispatchTask = nil
                        completionHandler()
                    }
                } else if connectHotspotRetryCount < 3 && !connectDispatchTask!.isCancelled {
                    if connectHotspotRetryCount == 0 {
                        // Schedule 10s timer for next two attempts at connecting to hotspot
                        DispatchQueue.main.sync {
                            connectionTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { timer in
                                self.connect(completionHandler: completionHandler, onError: onError)
                            }
                        }
                    }
                    
                    connectHotspotRetryCount += 1
                    print("Connection attempt \(connectHotspotRetryCount)")
                } else {
                    print("Connection to hotspot cancelled.")
                    
                    // Cancel connection to hotspot
                    DispatchQueue.main.sync {
                        connectionTimer?.invalidate()
                        connectionTimer = nil
                        connectDispatchTask = nil
                        connectHotspotRetryCount = 0
                        userRecentlyConnectedWhileOnTrustedNetwork = false
                        onError()
                    }
                }
            } catch {
                print(error.localizedDescription)
                
                // Cancel connection to hotspot
                DispatchQueue.main.sync {
                    connectionTimer?.invalidate()
                    connectionTimer = nil
                    connectDispatchTask = nil
                    connectHotspotRetryCount = 0
                    userRecentlyConnectedWhileOnTrustedNetwork = false
                    onError()
                    
                    // Disconnect from hotspot if connection failed
                    bluetoothModel.disconnectFromHotspot(systemControlling: false)
                }
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async(execute: connectDispatchTask!)
    }
    
    /**
     This function disconnects from the hotspot.
     - parameter indicateOnly: Whether the Mac should only update itself that hotspot has been disconnected
     - parameter systemControlling: Whether this app should disconnect from Wi-Fi for the user
     - parameter userInitiated: Whether the user initiated this disconnection
     */
    func disconnect(indicateOnly: Bool, systemControlling: Bool, userInitiated: Bool) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            // Cancel any attempts to connect to hotspot
            DispatchQueue.main.sync {
                connectDispatchTask?.cancel()
                connectionTimer?.invalidate()
                connectionTimer = nil
                connectHotspotRetryCount = 0
            }
            
            userRecentlyConnectedWhileOnTrustedNetwork = false
            
            if userInitiated {
                userRecentlyDisconnectedFromHotspot = true
            }
            
            // Disconnect from hotspot if needed
            if systemControlling {
                cwInterface.disassociate()
            }
        }
    }
    
    func linkDidChangeForWiFiInterface(withName interfaceName: String) {
        let currSsid = cwInterface.ssid()
        let linkState = currSsid != nil
        
        print("Link state changed: \(linkState)")
        
        if linkState {
            userRecentlyDisconnectedFromHotspot = false
        }
        
        if bluetoothModel.isDeviceConnected {
            syncMain {
                evalNotifyDisconnectHotspot()
                evalNotifyConnectHotspot()
                evalAutoEnableHotspot()
            }
        }
    }
    
    /**
     This function notifies the phone of a manual disconnection from hotspot.
     - parameter immediate: Whether the phone should be notified immediately
     */
    private func evalNotifyDisconnectHotspot(immediate: Bool = false) {
        let currSsid = cwInterface.ssid()
        if bluetoothModel.isConnectedToHotspot && currSsid != ssid {
            if immediate {
                print("Notifying disconnected from hotspot...")
                bluetoothModel.disconnectFromHotspot(systemControlling: false, userInitiated: currSsid == nil)
            } else {
                _ = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [self] timer in
                    evalNotifyDisconnectHotspot(immediate: true)
                }
            }
        }
    }
    
    /**
     This function notifies the phone of a manual connection from hotspot. This function runs immediately when executed.
     */
    private func evalNotifyConnectHotspot() {
        let currSsid = cwInterface.ssid()
        if !(bluetoothModel.isConnectedToHotspot || bluetoothModel.isConnectingToHotspot) && currSsid == ssid {
            print("Notifying connected to hotspot...")
            bluetoothModel.notifyConnectedToHotspot()
        }
    }
    
    /**
     This function automatically enables hotspot if known Wi-Fi networks are not available.
     - parameter immediate: Whether the evaluation if auto-connect is needed should be done immediately
     */
    func evalAutoEnableHotspot(immediate: Bool = false) {
        let currSsid = cwInterface.ssid()
        let linkState = currSsid != nil
        let isAutoConnect = defaults.bool(forKey: "autoConnect")
        
        if isAutoConnect && !isSleeping && !bluetoothModel.isLowBattery && !(bluetoothModel.isConnectedToHotspot || bluetoothModel.isConnectingToHotspot) && !linkState && !userRecentlyDisconnectedFromHotspot {
            if immediate {
                print("Enabling hotspot because known Wi-Fi network is not available")
                bluetoothModel.enableHotspot()
            } else {
                _ = Timer.scheduledTimer(withTimeInterval: 7, repeats: false) { [self] timer in
                    evalAutoEnableHotspot(immediate: true)
                }
            }
        }
    }
    
    func scanCacheUpdatedForWiFiInterface(withName interfaceName: String) {
        print("Scan cache updated")
        let useTrustedNetworks = defaults.bool(forKey: "useTrustedNetworks")
        
        if let networks = cwInterface.cachedScanResults() {
            // Check for available trusted networks
            let trustedNetworkSSIDsArr = defaults.stringArray(forKey: "trustedNetworks") ?? []
            let trustedNetworkSSIDs = Set(trustedNetworkSSIDsArr)
            let trustedNetworkPasswords = defaults.stringArray(forKey: "trustedNetworkPasswords") ?? []
            let availableNetworkSSIDs = Set(networks.map { $0.ssid ?? "" })
            let availableTrustedNetworkSSIDs = trustedNetworkSSIDs.intersection(availableNetworkSSIDs)
            
            if let firstAvailableTrustedNetwork = availableTrustedNetworkSSIDs.first {
                if useTrustedNetworks && bluetoothModel.isConnectedToHotspot && !userRecentlyConnectedWhileOnTrustedNetwork {
                    // Connect to the first trusted network if it is available and user did not connect to hotspot on trusted network
                    do {
                        print("Found trusted network!")
                        let network = networks.first(where: { $0.ssid == firstAvailableTrustedNetwork })!
                        let password = trustedNetworkPasswords[trustedNetworkSSIDsArr.firstIndex(of: firstAvailableTrustedNetwork)!]
                        try cwInterface.associate(to: network, password: password)
                        
                        // Disconnect from hotspot if successfully connected to trusted network
                        DispatchQueue.main.sync {
                            bluetoothModel.disconnectFromHotspot(systemControlling: false)
                        }
                    } catch {
                        print("Failed to associate to trusted network \(firstAvailableTrustedNetwork): \(error.localizedDescription)")
                        
                        // Re-scan for networks in case the error was caused by outdated scan cache
                        do {
                            try cwInterface.scanForNetworks(withName: nil)
                        } catch {
                            print("Failed to scan for networks: \(error.localizedDescription)")
                        }
                    }
                }
            }
        } else {
            userRecentlyConnectedWhileOnTrustedNetwork = false
        }
    }
    
    /**
     This function helps reset all hotspot settings for setup again.
     */
    func reset() {
        // Cancel all tasks
        connectDispatchTask?.cancel()
        connectionTimer?.invalidate()
        
        // Reset all variables
        connectDispatchTask = nil
        ssid = nil
        password = nil
        connectHotspotRetryCount = 0
        connectionTimer = nil
        userRecentlyConnectedWhileOnTrustedNetwork = false
        userRecentlyDisconnectedFromHotspot = false
        
        do {
            try cwWiFiClient.stopMonitoringAllEvents()
        } catch {
            print("Error while resetting WLANModel: \(error.localizedDescription)")
        }
    }
}
