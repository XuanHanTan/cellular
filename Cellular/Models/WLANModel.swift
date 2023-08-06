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
    var ssid: String?
    private var password: String?
    private var connectHotspotRetryCount = 0
    private var connectionTimer: Timer?
    
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
        
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            do {
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
                        completionHandler()
                    }
                } else if (connectHotspotRetryCount < 3) {
                    _ = DispatchQueue.main.sync {
                        connectionTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { timer in
                            DispatchQueue.global(qos: .userInitiated).async {
                                self.connect(completionHandler: completionHandler, onError: onError)
                            }
                        }
                    }
                    
                    connectHotspotRetryCount += 1
                    print("Connection attempt \(connectHotspotRetryCount)")
                } else {
                    connectHotspotRetryCount = 0
                    
                    DispatchQueue.main.sync {
                        onError()
                    }
                }
            } catch {
                print(error.localizedDescription)
                
                connectHotspotRetryCount = 0
                
                DispatchQueue.main.sync {
                    onError()
                }
            }
        }
    }
    
    func disconnect(indicateOnly: Bool) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            connectionTimer?.invalidate()
            if !indicateOnly {
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
            bluetoothModel.userRecentlyDisconnectedFromHotspot = false
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
        
        if useTrustedNetworks && (bluetoothModel.isConnectedToHotspot || bluetoothModel.isConnectingToHotspot), let networks = cwInterface.cachedScanResults() {
            let trustedNetworkSSIDs = Set(defaults.stringArray(forKey: "trustedNetworks") ?? [])
            let availabeNetworkSSIDs = Set(networks.map { $0.ssid ?? "" })
            let availableTrustedNetworkSSIDs = trustedNetworkSSIDs.intersection(availabeNetworkSSIDs)
            // TODO: allow saving password
            
            if let firstAvailableTrustedNetwork = availableTrustedNetworkSSIDs.first {
                do {
                    DispatchQueue.main.sync {
                        bluetoothModel.userDisconnectFromHotspot(indicateOnly: true)
                    }
                    let network = networks.first(where: { $0.ssid == firstAvailableTrustedNetwork })!
                    try cwInterface.associate(to: network, password: nil)
                } catch {
                    print("Failed to associate to trusted network \(firstAvailableTrustedNetwork): \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func evalIndicateDisconnectHotspot(immediate: Bool = false) {
        func startIndicateDisconnectHotspot() {
            print("Indicating disconnected from hotspot...")
            bluetoothModel.userDisconnectFromHotspot(indicateOnly: true)
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
            bluetoothModel.indicateConnectedToHotspot()
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
        
        if isAutoConnect && !bluetoothModel.isLowBattery && !(bluetoothModel.isConnectedToHotspot || bluetoothModel.isConnectingToHotspot) && !linkState && !bluetoothModel.userRecentlyDisconnectedFromHotspot {
            if immediate {
                startAutoEnableHotspot()
            } else {
                _ = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [self] timer in
                    evalAutoEnableHotspot(immediate: true)
                }
            }
        }
    }
    
    func dispose() {
        connectHotspotRetryCount = 0
        ssid = ""
        password = ""
    }
}
