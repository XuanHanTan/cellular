//
//  MenuBarContentView.swift
//  Cellular
//
//  Created by Xuan Han on 25/6/23.
//

import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var bluetoothModel: BluetoothModel
    @Binding var isMenuBarItemPresented: Bool
    @State private var isSetupComplete = false
    
    var body: some View {
        VStack {
            if isSetupComplete {
                HStack {
                    Text("Connected").font(.title2).fontWeight(.semibold)
                    Spacer()
                    Button {
                        isMenuBarItemPresented = false
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                        NSApp.activate(ignoringOtherApps: true)
                    } label: {
                        Image(systemName: "gearshape").font(.title2).foregroundColor(.primary)
                    }.buttonStyle(.borderless)
                }
                Spacer()
            } else {
                Spacer()
                Image(systemName: "exclamationmark.circle")
                    .font(Font.system(size: 50, design: .default))
                    .padding(.bottom, 10)
                Text("This menu will be available once setup completes.")
                    .font(.title2)
                    .multilineTextAlignment(.center)
                Spacer()
            }
        }
        .frame(width: 300, height: 400)
        .padding(.all, 20)
        .onReceive(bluetoothModel.$isSetupComplete) { isSetupComplete in
            self.isSetupComplete = isSetupComplete
        }
    }
}
