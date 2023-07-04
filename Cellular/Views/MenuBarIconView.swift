//
//  MenuBarIconView.swift
//  Cellular
//
//  Created by Xuan Han on 25/6/23.
//

import SwiftUI

struct MenuBarIconView: View {
    @ObservedObject var bluetoothModel: BluetoothModel
    @State private var isSetupComplete = false
    @State private var signalLevel = -1
    @State private var networkType = "-1"
    @State private var batteryLevel = -1
    
    var body: some View {
        HStack {
            if isSetupComplete {
                Image("cellularbars.\(signalLevel)")
                if networkType != "-1" {
                    Text(networkType)
                }
                if batteryLevel == -1 {
                    Image(systemName: "battery.0")
                } else if batteryLevel % 25 == 0 {
                    Image(systemName: "battery.\(batteryLevel)")
                }
            } else {
                Image(systemName: "cellularbars")
            }
        }.onReceive(bluetoothModel.$isSetupComplete) { isSetupComplete in
            self.isSetupComplete = isSetupComplete
        }.onReceive(bluetoothModel.$signalLevel) { signalLevel in
            self.signalLevel = signalLevel
        }.onReceive(bluetoothModel.$networkType) { networkType in
            self.networkType = networkType
        }.onReceive(bluetoothModel.$batteryLevel) { batteryLevel in
            self.batteryLevel = batteryLevel
        }.onAppear {
            bluetoothModel.initializeBluetooth()
        }
    }
}
