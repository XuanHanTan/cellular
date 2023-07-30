//
//  MenuBarIconView.swift
//  Cellular
//
//  Created by Xuan Han on 25/6/23.
//

import SwiftUI

struct MenuBarIconView: View {
    @ObservedObject var bluetoothModel: BluetoothModel
    @AppStorage("seePhoneInfo") var seePhoneInfo = true
    
    var body: some View {
        HStack {
            if bluetoothModel.isSetupComplete && bluetoothModel.isDeviceConnected {
                if seePhoneInfo && bluetoothModel.signalLevel != -1 && bluetoothModel.networkType != "-1" && bluetoothModel.batteryLevel != -1 {
                    Image("cellularbars.\(bluetoothModel.signalLevel)")
                } else {
                    Image(systemName: "iphone.gen3")
                }
            } else {
                Image(systemName: "iphone.gen3.slash")
            }
        }
        .onAppear {
            if bluetoothModel.isSetupComplete {
                bluetoothModel.initializeBluetooth()
            }
        }
    }
}
