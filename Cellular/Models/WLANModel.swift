//
//  WLANModel.swift
//  Cellular
//
//  Created by Xuan Han on 23/7/23.
//

import Foundation
import CoreWLAN

class WLANModel: CWEventDelegate {
    private let cwWiFiClient = CWWiFiClient()
    private var connectHotspotRetryCount = 0
    
    func connect(ssid: String, password: String, onSuccess: @escaping () -> Void, onError: @escaping () -> Void) {
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
                        onSuccess()
                    }
                } else if (connectHotspotRetryCount < 3) {
                    _ = DispatchQueue.main.sync {
                        Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { timer in
                            DispatchQueue.global(qos: .userInitiated).async {
                                self.connect(ssid: ssid, password: password, onSuccess: onSuccess, onError: onError)
                            }
                        }
                    }
                    
                    connectHotspotRetryCount += 1
                    print("Connection attempt \(connectHotspotRetryCount)")
                } else {
                    connectHotspotRetryCount = 0
                    onError()
                }
            } catch {
                print(error.localizedDescription)
                connectHotspotRetryCount = 0
                onError()
            }
        }
    }
    
    func disconnect(onSuccess: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let cwInterface = cwWiFiClient.interface()!
            cwInterface.disassociate()
            
            DispatchQueue.main.sync {
                onSuccess()
            }
        }
    }
    
    func dispose() {
        connectHotspotRetryCount = 0
    }
}
