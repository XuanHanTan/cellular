//
//  SettingsView.swift
//  Cellular
//
//  Created by Xuan Han on 24/6/23.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @State private var path = NavigationPath()
    
    @ObservedObject var wlanModel: WLANModel
    
    @AppStorage("autoConnect") var isAutoConnect = false
    @AppStorage("autoDisconnectWhenSleep") var isAutoDisconnectWhenSleep = false
    // @AppStorage("autoDisconnectWhenTrustedWiFiAvailable") var isAutoDisconnectWhenTrustedWiFiAvailableOn = false
    @AppStorage("minimumBatteryLevel") var minimumBatteryLevel = 0
    @AppStorage("seePhoneInfo") var seePhoneInfo = true
    
    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                Form {
                    Section {
                        NavigationLink(value: "trustedNetworksSettingsView") {
                            HStack(spacing: 10) {
                                Image(systemName: "wifi")
                                    .frame(width: 20, height: 20)
                                    .background(.blue.gradient)
                                    .cornerRadius(5)
                                Text("Trusted networks")
                                Spacer()
                            }
                        }.navigationBarBackButtonHidden(true)
                    }
                    Section {
                        Toggle(isOn: $isAutoConnect) {
                            Text("Connect when known Wi-Fi networks are unavailable")
                        }
                        .toggleStyle(.switch)
                        .onChange(of: isAutoConnect) { isAutoConnect in
                            if isAutoConnect {
                                wlanModel.evalAutoEnableHotspot(immediate: true)
                            }
                        }
                        Toggle(isOn: $isAutoDisconnectWhenSleep) {
                            Text("Disconnect when your Mac is put to sleep")
                        }
                        .toggleStyle(.switch)
                        /*Toggle(isOn: $isAutoDisconnectWhenTrustedWiFiAvailableOn) {
                         Text("Disconnect when trusted Wi-Fi networks are available")
                         }
                         .toggleStyle(.switch)*/
                        Picker("Disconnect when phone battery is below", selection: $minimumBatteryLevel) {
                            Text("Never")
                                .tag(0)
                            Text("10%")
                                .tag(10)
                            Text("20%")
                                .tag(20)
                            Text("30%")
                                .tag(30)
                            Text("40%")
                                .tag(40)
                            Text("50%")
                                .tag(50)
                        }
                        Toggle(isOn: $seePhoneInfo) {
                            Text("See phone information on your Mac")
                            Text("Allow your Mac to display your phone’s network signal strength, mobile network type and battery level. This will consume more energy on both devices.")
                        }
                        .toggleStyle(.switch)
                        .onChange(of: seePhoneInfo) { seePhoneInfo in
                            if seePhoneInfo {
                                bluetoothModel.enableSeePhoneInfo()
                            } else {
                                bluetoothModel.disableSeePhoneInfo()
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .padding(.bottom, 10)
                HStack {
                    Button("Contact the creator...") {
                        let url = URL(string: "mailto:contactxuanhan@gmail.com")!
                        openURL(url)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.all, 20)
            }
            .frame(minWidth: 600, idealWidth: 600, maxWidth: 600,
                   minHeight: 400, idealHeight: 400, maxHeight: 400,
                   alignment: .center)
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { newValue in
                NSApp.setActivationPolicy(.accessory)
            }
            .navigationDestination(for: String.self) { textValue in
                if textValue == "trustedNetworksSettingsView" {
                    TrustedNetworksSettingsView(path: $path)
                }
            }
        }
    }
}
