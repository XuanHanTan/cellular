//
//  ContentView.swift
//  Cellular
//
//  Created by Xuan Han on 5/6/23.
//

import SwiftUI

struct ContentView: View {
    @StateObject var bluetoothViewModel = BluetoothViewModel()
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
            Button("Test") {
                bluetoothViewModel.initializeBluetooth()
            }
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
