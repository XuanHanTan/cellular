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
    @AppStorage("seePhoneInfo") var seePhoneInfo = true
    
    func getBluetoothError() -> String {
        if bluetoothModel.isBluetoothOffDialogPresented {
            return "Enable Bluetooth to use Cellular"
        } else if bluetoothModel.isBluetoothNotGrantedDialogPresented {
            return "Bluetooth permission is not granted"
        } else if bluetoothModel.isBluetoothNotSupportedDialogPresented {
            return "Bluetooth is not supported"
        } else {
            return "An unknown error occured"
        }
    }
    
    func getHotspotStatus() -> String {
        if bluetoothModel.isConnectedToHotspot {
            return "Connected"
        } else if bluetoothModel.isConnectingToHotspot {
            return "Connecting"
        } else if bluetoothModel.isDeviceConnected {
            return "Idle"
        } else {
            return "Disconnected"
        }
    }
    
    var body: some View {
        VStack {
            if !bluetoothModel.isPoweredOn && bluetoothModel.isSetupComplete {
                HStack {
                    Spacer()
                    Image(systemName: "exclamationmark.circle")
                        .font(.title3)
                        .padding(.trailing, 2)
                    Text(getBluetoothError())
                        .font(.title3)
                        .padding(.bottom, 1)
                    Spacer()
                }
                .padding(.vertical, 10)
                .background(Color(hex: 0xA91C1C))
            }
            VStack {
                if bluetoothModel.isSetupComplete {
                    HStack {
                        Text(getHotspotStatus())
                            .font(.title2)
                            .fontWeight(.semibold)
                        Spacer()
                        Button {
                            isMenuBarItemPresented = false
                            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                            NSApp.activate(ignoringOtherApps: true)
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.title2)
                                .foregroundColor(.primary)
                                .padding(.bottom, 1)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 30)
                    HStack(spacing: 0) {
                        if bluetoothModel.isDeviceConnected {
                            if seePhoneInfo && bluetoothModel.signalLevel != -1 && bluetoothModel.networkType != "-1" && bluetoothModel.batteryLevel != -1 {
                                Image("cellularbars.\(bluetoothModel.signalLevel)")
                                    .font(.title3)
                                    .padding(.trailing, 6)
                                if bluetoothModel.networkType != "-1" {
                                    Text(bluetoothModel.networkType)
                                        .font(.title3)
                                        .padding(.trailing, 6)
                                }
                                if bluetoothModel.batteryLevel == -1 {
                                    Image(systemName: "battery.0")
                                        .font(.title2)
                                        .padding(.bottom, 1)
                                } else if bluetoothModel.batteryLevel % 25 == 0 {
                                    Image(systemName: "battery.\(bluetoothModel.batteryLevel)")
                                        .font(.title2)
                                        .padding(.bottom, 1)
                                }
                            } else {
                                Image("phone")
                                    .font(.title2)
                            }
                        } else {
                            Image("no.service")
                                .font(.title2)
                        }
                    }.frame(height: 15)
                    Spacer()
                    Button {
                        if bluetoothModel.isConnectedToHotspot || bluetoothModel.isConnectingToHotspot {
                            bluetoothModel.disconnectFromHotspot()
                        } else {
                            bluetoothModel.enableHotspot()
                        }
                    } label: {
                        if bluetoothModel.isConnectedToHotspot {
                            Image(systemName: "personalhotspot")
                                .font(Font.system(size: 30, design: .default))
                                .padding(.all, 64)
                                .foregroundColor(Color(hex: colorScheme == .dark ? 0x35D11B: 0x1C850B))
                                .background(Color(hex: colorScheme == .dark ? 0x292F28: 0xDCF4D6))
                                .clipShape(Circle())
                                .overlay {
                                    Circle().strokeBorder(Color(hex: colorScheme == .dark ? 0x5C8C54: 0x8FD684), lineWidth: 4)
                                }
                        } else if bluetoothModel.isConnectingToHotspot {
                            Circle()
                                .foregroundColor(Color(hex: colorScheme == .dark ? 0x313131: 0xF0F0F0))
                                .overlay {
                                    ZStack {
                                        ProgressView()
                                    }
                                    .frame(width: 30, height: 30)
                                    .padding(.all, 0)
                                    Circle().strokeBorder(Color(hex: colorScheme == .dark ? 0x505050: 0xD6D6D6), lineWidth: 4)
                                }.frame(width: 30 + 64 + 64, height: 30 + 64 + 64)
                        } else {
                            Image(systemName: "personalhotspot")
                                .font(Font.system(size: 30, design: .default))
                                .padding(.all, 64)
                                .foregroundColor(Color(hex: 0x848484))
                                .background(Color(hex: colorScheme == .dark ? 0x313131: 0xF0F0F0))
                                .clipShape(Circle())
                                .overlay {
                                    Circle().strokeBorder(Color(hex: colorScheme == .dark ? 0x505050: 0xD6D6D6), lineWidth: 4)
                                }
                        }
                    }
                    .frame(width: 200, height: 200)
                    .buttonStyle(.plain)
                    .disabled(!bluetoothModel.isDeviceConnected)
                    Spacer()
                } else {
                    HStack {
                        Spacer()
                    }
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
            .padding(.horizontal, 20)
            .padding(.top, bluetoothModel.isPoweredOn ? 20: 10)
            .padding(.bottom, 20)
        }
        .background(colorScheme == .dark ? Color(hex: 0x1A1C18): Color(hex: 0xFCFDF6))
    }
}
