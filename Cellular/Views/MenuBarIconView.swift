//
//  MenuBarIconView.swift
//  Cellular
//
//  Created by Xuan Han on 25/6/23.
//

import SwiftUI

struct MenuBarIconView: View {
    @ObservedObject var bluetoothModel: BluetoothModel
    
    var body: some View {
        HStack {
            if bluetoothModel.isSetupComplete && bluetoothModel.isDeviceConnected {
                Image("cellularbars.\(bluetoothModel.signalLevel)")
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
