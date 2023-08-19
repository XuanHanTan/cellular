//
//  CellularApp.swift
//  Cellular
//
//  Created by Xuan Han on 5/6/23.
//

import SwiftUI
import MenuBarExtraAccess

let wlanModel = WLANModel()
let bluetoothModel = BluetoothModel()
var isSleeping = false

@main
struct CellularApp: App {
    @Environment(\.openWindow) private var openWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @State private var menuBarItemPresented = false
    @StateObject private var wlanModel = Cellular.wlanModel
    @StateObject private var bluetoothModel = Cellular.bluetoothModel
    @State private var path = NavigationPath()
    
    var body: some Scene {
        WindowGroup(id: "main") {
            NavigationStack(path: $path) {
                StartView(path: $path)
                    .navigationDestination(for: String.self) { textValue in
                        switch textValue {
                            case "downloadAppView":
                                DownloadAppView(path: $path)
                            case "qrCodeView":
                                QRCodeView(path: $path)
                            case "settingUpView":
                                SettingUpView(path: $path)
                            case "finishSetupView":
                                FinishSetupView(path: $path)
                            default:
                                EmptyView()
                        }
                    }
            }
            .alert("Turn on Bluetooth", isPresented: $bluetoothModel.isBluetoothOffDialogPresented) {
            } message: {
                Text("You must leave Bluetooth on so Cellular can remain connected to your Android device.")
            }
            .alert("Grant the Bluetooth permission", isPresented: $bluetoothModel.isBluetoothNotGrantedDialogPresented) {
            } message: {
                Text("The Bluetooth permission is required for Cellular to communicate with your Android device using Bluetooth. Please grant it in System Settings.")
            }
            .alert("An unknown error occurred", isPresented: $bluetoothModel.isBluetoothUnknownErrorDialogPresented) {
            } message: {
                Text("Cellular is not able to communicate with the Bluetooth service and will retry automatically.")
            }.onAppear {
                if !bluetoothModel.isSetupComplete {
                    // Make app a regular app to show the setup window
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
                
                bluetoothModel.registerResetCompletionHandler {
                    let prevActivationPolicy = NSApp.activationPolicy()
                    
                    menuBarItemPresented = false
                    
                    // Make app a regular app to show the setup window
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    
                    path.removeLast(path.count)
                    if prevActivationPolicy != .regular {
                        NSApplication.shared.keyWindow?.close()
                        openWindow(id: "main")
                    }
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            // Disable new window command in Menu Bar
            CommandGroup(replacing: CommandGroupPlacement.newItem) {
            }
        }
        Settings {
            if bluetoothModel.isSetupComplete {
                SettingsView(wlanModel: wlanModel) {
                    NSApplication.shared.keyWindow?.close()
                    bluetoothModel.reset()
                    wlanModel.reset()
                }
            }
        }
        .windowResizability(.contentSize)
        MenuBarExtra(
            content: {
                MenuBarContentView(bluetoothModel: bluetoothModel, isMenuBarItemPresented: $menuBarItemPresented)
                    .frame(width: 280, height: 400)
            },
            label: {
                MenuBarIconView(bluetoothModel: bluetoothModel)
            }
        )
        .menuBarExtraStyle(.window)
        .menuBarExtraAccess(isPresented: $menuBarItemPresented)
    }
}
