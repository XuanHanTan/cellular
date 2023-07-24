//
//  WLANModel.swift
//  Cellular
//
//  Created by Xuan Han on 23/7/23.
//

import Foundation
import CoreWLAN

class WLANModel: CWEventDelegate {
    let bluetoothModel: BluetoothModel
    
    private let cwWiFiClient = CWWiFiClient.shared()
    private var ssid: String?
    private var password: String?
    private var connectHotspotRetryCount = 0
    
    init(bluetoothModel: BluetoothModel) {
        self.bluetoothModel = bluetoothModel
        cwWiFiClient.delegate = self
        
        do {
            try cwWiFiClient.startMonitoringEvent(with: .linkDidChange)
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
            let cwInterface = cwWiFiClient.interface()!
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
                        Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { timer in
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
    
    func disconnect() {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let cwInterface = cwWiFiClient.interface()!
            cwInterface.disassociate()
        }
    }
    
    /// Temporary info (will be tidied up later):
    ///  1. Disconnect from hotspot when network ssid is not hotspot ssid and hotspot is supposed to be connected
    ///  2. Indicate to android device that hotspot has been connected if hotspot connected when not supposed to
    func linkDidChangeForWiFiInterface(withName interfaceName: String) {
        let currSsid = cwWiFiClient.interface(withName: interfaceName)?.ssid()
        let linkState = currSsid != ""
        
        print("Link state changed: \(linkState)")
        
        if bluetoothModel.isConnectedToHotspot && currSsid != ssid {
            print("Indicating disconnected to hotspot...")
            bluetoothModel.userDisconnectFromHotspot(indicateOnly: true)
        } else if !(bluetoothModel.isConnectedToHotspot || bluetoothModel.isConnectingToHotspot) && currSsid == ssid {
            print("Indicating connected to hotspot...")
            bluetoothModel.indicateConnectedToHotspot()
        }
    }
    
    func dispose() {
        connectHotspotRetryCount = 0
        ssid = ""
        password = ""
    }
}
