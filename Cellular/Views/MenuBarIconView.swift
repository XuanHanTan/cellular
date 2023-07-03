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
    
    var body: some View {
        HStack {
            if isSetupComplete {
                Text("5G")
            } else {
                Image(systemName: "cellularbars")
            }
        }.onReceive(bluetoothModel.$isSetupComplete) { isSetupComplete in
            self.isSetupComplete = isSetupComplete
        }.onAppear {
            bluetoothModel.initializeBluetooth()
        }
    }
}
