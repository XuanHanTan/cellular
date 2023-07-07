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
    @State private var isDeviceConnected = false
    @State private var signalLevel = -1
    @State private var networkType = "-1"
    @State private var batteryLevel = -1
    
    var body: some View {
        HStack {
            if isSetupComplete && isDeviceConnected {
                Image("cellularbars.\(signalLevel)").imageScale(.large)
            } else {
                Image(systemName: "iphone.gen3.slash")
            }
        }.onReceive(bluetoothModel.$isSetupComplete) { isSetupComplete in
            self.isSetupComplete = isSetupComplete
        }.onReceive(bluetoothModel.$isDeviceConnected) { isDeviceConnected in
            self.isDeviceConnected = isDeviceConnected
        }.onReceive(bluetoothModel.$signalLevel) { signalLevel in
            self.signalLevel = 3
        }.onAppear {
            bluetoothModel.initializeBluetooth()
        }
    }
}
