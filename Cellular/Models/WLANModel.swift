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
    
    func setHotspotDetails(ssid: String, password: String) {
        self.ssid = ssid
        self.password = password
    }
    
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
                if let currentSSID = cwInterface.ssid() {
                    let trustedNetworkSSIDs = defaults.stringArray(forKey: "trustedNetworks") ?? []
                    if trustedNetworkSSIDs.contains(currentSSID) {
                        userRecentlyConnectedWhileOnTrustedNetwork = true
                    }
                }
                
                var selNetwork: CWNetwork? = nil
                for network in try cwInterface.scanForNetworks(withName: ssid) {
                    if network.ssid == ssid {
                        selNetwork = network
                    }
                }
                if selNetwork != nil {
                    try cwInterface.associate(to: selNetwork!, password: password)
                    
                    DispatchQueue.main.sync {
                        connectHotspotRetryCount = 0
                        connectDispatchTask = nil
                        completionHandler()
                    }
                } else if connectHotspotRetryCount < 3 && !connectDispatchTask!.isCancelled {
                    if connectHotspotRetryCount == 0 {
                        _ = DispatchQueue.main.sync {
                            connectionTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { timer in
                                self.connect(completionHandler: completionHandler, onError: onError)
                            }
                        }
                    }
                    
                    connectHotspotRetryCount += 1
                    print("Connection attempt \(connectHotspotRetryCount)")
                } else {
                    connectHotspotRetryCount = 0
                    
                    DispatchQueue.main.sync {
                        connectDispatchTask = nil
                        userRecentlyConnectedWhileOnTrustedNetwork = false
                        onError()
                    }
                }
            } catch {
                print(error.localizedDescription)
                
                connectHotspotRetryCount = 0
                
                DispatchQueue.main.sync {
                    connectDispatchTask = nil
                    userRecentlyConnectedWhileOnTrustedNetwork = false
                    onError()
                }
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async(execute: connectDispatchTask!)
    }
    
    func disconnect(indicateOnly: Bool, systemControlling: Bool, userInitiated: Bool) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            DispatchQueue.main.sync {
                connectDispatchTask?.cancel()
                connectionTimer?.invalidate()
                connectionTimer = nil
            }
            
            userRecentlyConnectedWhileOnTrustedNetwork = false
            if userInitiated {
                userRecentlyDisconnectedFromHotspot = true
            }
            
            if systemControlling {
                cwInterface.disassociate()
            }
        }
    }
    
    /// Temporary info (will be tidied up later):
    ///  1. Disconnect from hotspot when network ssid is not hotspot ssid and hotspot is supposed to be connected
    ///  2. Indicate to android device that hotspot has been connected if hotspot connected when not supposed to
    ///  3. Connect to hotspot when device is not connecting/connected to hotspot and user has not disconnected from hotspot recently
    func linkDidChangeForWiFiInterface(withName interfaceName: String) {
        let currSsid = cwInterface.ssid()
        let linkState = currSsid != nil
        
        print("Link state changed: \(linkState)")
        
        if linkState {
            userRecentlyDisconnectedFromHotspot = false
        }
        
        if bluetoothModel.isDeviceConnected {
            syncMain {
                evalIndicateDisconnectHotspot()
                evalIndicateConnectHotspot()
                evalAutoEnableHotspot()
            }
        }
    }
    
    func scanCacheUpdatedForWiFiInterface(withName interfaceName: String) {
        print("Scan cache updated")
        let useTrustedNetworks = defaults.bool(forKey: "useTrustedNetworks")
        
        if let networks = cwInterface.cachedScanResults() {
            let trustedNetworkSSIDsArr = defaults.stringArray(forKey: "trustedNetworks") ?? []
            let trustedNetworkSSIDs = Set(trustedNetworkSSIDsArr)
            let trustedNetworkPasswords = defaults.stringArray(forKey: "trustedNetworkPasswords") ?? []
            let availabeNetworkSSIDs = Set(networks.map { $0.ssid ?? "" })
            let availableTrustedNetworkSSIDs = trustedNetworkSSIDs.intersection(availabeNetworkSSIDs)
            
            
            if let firstAvailableTrustedNetwork = availableTrustedNetworkSSIDs.first {
                if useTrustedNetworks && (bluetoothModel.isConnectedToHotspot || bluetoothModel.isConnectingToHotspot) && !userRecentlyConnectedWhileOnTrustedNetwork {
                    do {
                        DispatchQueue.main.sync {
                            bluetoothModel.disconnectFromHotspot()
                        }
                        let network = networks.first(where: { $0.ssid == firstAvailableTrustedNetwork })!
                        let password = trustedNetworkPasswords[trustedNetworkSSIDsArr.firstIndex(of: firstAvailableTrustedNetwork)!]
                        try cwInterface.associate(to: network, password: password)
                    } catch {
                        print("Failed to associate to trusted network \(firstAvailableTrustedNetwork): \(error.localizedDescription)")
                    }
                }
            }
        } else {
            userRecentlyConnectedWhileOnTrustedNetwork = false
        }
    }
    
    private func evalIndicateDisconnectHotspot(immediate: Bool = false) {
        func startIndicateDisconnectHotspot() {
            print("Disconnecting from hotspot...")
            bluetoothModel.disconnectFromHotspot(systemControlling: false, userInitiated: true)
        }
        
        let currSsid = cwInterface.ssid()
        if bluetoothModel.isConnectedToHotspot && currSsid != ssid {
            if immediate {
                startIndicateDisconnectHotspot()
            } else {
                _ = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [self] timer in
                    evalIndicateDisconnectHotspot(immediate: true)
                }
            }
        }
    }
    
    private func evalIndicateConnectHotspot() {
        let currSsid = cwInterface.ssid()
        if !(bluetoothModel.isConnectedToHotspot || bluetoothModel.isConnectingToHotspot) && currSsid == ssid {
            print("Indicating connected to hotspot...")
            bluetoothModel.notifyConnectedToHotspot()
        }
    }
    
    func evalAutoEnableHotspot(immediate: Bool = false) {
        func startAutoEnableHotspot() {
            print("Enabling hotspot because known Wi-Fi network is not available")
            bluetoothModel.enableHotspot()
        }
        
        let currSsid = cwInterface.ssid()
        let linkState = currSsid != nil
        let isAutoConnect = defaults.bool(forKey: "autoConnect")
        
        if isAutoConnect && !isSleeping && !bluetoothModel.isLowBattery && !(bluetoothModel.isConnectedToHotspot || bluetoothModel.isConnectingToHotspot) && !linkState && !userRecentlyDisconnectedFromHotspot {
            if immediate {
                startAutoEnableHotspot()
            } else {
                _ = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [self] timer in
                    evalAutoEnableHotspot(immediate: true)
                }
            }
        }
    }
    
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
