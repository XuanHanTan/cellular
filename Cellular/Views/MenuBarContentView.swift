//
//  MenuBarContentView.swift
//  Cellular
//
//  Created by Xuan Han on 25/6/23.
//

import SwiftUI

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}

struct MenuBarContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var bluetoothModel: BluetoothModel
    @Binding var isMenuBarItemPresented: Bool
    @State private var isSetupComplete = false
    @State private var isDeviceConnected = false
    @State private var isConnectingToHotspot = false
    @State private var isConnectedToHotspot = false
    @State private var signalLevel = -1
    @State private var networkType = "-1"
    @State private var batteryLevel = -1
    
    func getHotspotStatus() -> String {
        if isConnectedToHotspot {
            return "Connected"
        } else if isConnectingToHotspot {
            return "Connecting"
        } else if isDeviceConnected {
            return "Idle"
        } else {
            return "Disconnected"
        }
    }
    
    var body: some View {
        VStack {
            VStack {
                if isSetupComplete {
                    HStack {
                        Text(getHotspotStatus()).font(.title2).fontWeight(.semibold)
                        Spacer()
                        Button {
                            isMenuBarItemPresented = false
                            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                            NSApp.activate(ignoringOtherApps: true)
                        } label: {
                            Image(systemName: "gearshape").font(.title2).foregroundColor(.primary)
                        }.buttonStyle(.borderless)
                    }.padding(.bottom, 30)
                    if isDeviceConnected {
                        HStack(spacing: 0) {
                            Image("cellularbars.\(signalLevel)").padding(.trailing, 7.5)
                            if networkType != "-1" {
                                Text(networkType).font(.title3).padding(.trailing, 6)
                            }
                            if batteryLevel == -1 {
                                Image(systemName: "battery.0").font(.title2).padding(.bottom, 1)
                            } else if batteryLevel % 25 == 0 {
                                Image(systemName: "battery.\(batteryLevel)").font(.title2).padding(.bottom, 1)
                            }
                        }
                    } else {
                        Image(systemName: "iphone.gen3.slash").font(.title2)
                    }
                    Spacer()
                    Button {
                        bluetoothModel.enableHotspot()
                    } label: {
                        Image(systemName: "personalhotspot")
                            .font(Font.system(size: 30, design: .default))
                            .padding(.all, 64)
                            .foregroundColor(Color(hex: colorScheme == .dark ? 0x35D11B: 0x1C850B))
                            .background(Color(hex: colorScheme == .dark ? 0x292F28: 0xDCF4D6))
                            .clipShape(Circle())
                            .overlay {
                                Circle().strokeBorder(Color(hex: colorScheme == .dark ? 0x5C8C54: 0x8FD684), lineWidth: 4)
                            }
                    }.frame(width: 200, height: 200).buttonStyle(.plain)
                    Spacer()
                    Text("Cellular will disconnect when a trusted network is available.")
                        .font(.title3)
                        .multilineTextAlignment(.center).padding(.bottom, 10)
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
            .padding(.all, 20)
            .onReceive(bluetoothModel.$isSetupComplete) { isSetupComplete in
                self.isSetupComplete = isSetupComplete
            }.onReceive(bluetoothModel.$isDeviceConnected) { isDeviceConnected in
                self.isDeviceConnected = isDeviceConnected
            }.onReceive(bluetoothModel.$signalLevel) { signalLevel in
                self.signalLevel = signalLevel
            }.onReceive(bluetoothModel.$networkType) { networkType in
                self.networkType = networkType
            }.onReceive(bluetoothModel.$batteryLevel) { batteryLevel in
                self.batteryLevel = batteryLevel
            }
        }
        .background(colorScheme == .dark ? Color(hex: 0x1A1C18): Color(hex: 0xFCFDF6))
    }
}
