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

/**
 This function displays the about panel.
 */
func openAboutPanel() {
    NSApplication.shared.orderFrontStandardAboutPanel(
        options: [
            NSApplication.AboutPanelOptionKey.version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String,
            NSApplication.AboutPanelOptionKey.credits: NSAttributedString(
                string: "This app was developed by Xuan Han Tan. I hope you find it useful! If you want to learn more about me and my other projects, visit my website. If you have any questions, feel free to contact me by email.",
                attributes: [
                    NSAttributedString.Key.font: NSFont.systemFont(ofSize: NSFont.labelFontSize),
                ]
            ),
            NSApplication.AboutPanelOptionKey(
                rawValue: "Copyright"
            ): "© Xuan Han Tan 2023. All rights reserved.",
        ]
    )
}

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
                            case "trustedNetworksSetupView":
                                TrustedNetworkSetupView(path: $path)
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
                    
                    // Close menu bar item
                    menuBarItemPresented = false
                    
                    // Make app a regular app to show the setup window
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    
                    // Go back to first page (StartView) in navigation stack
                    path.removeLast(path.count)
                    
                    // Close settings window if it is open, and open the main setup window
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
            CommandGroup(replacing: .appInfo) {
                Button("About") {
                   openAboutPanel()
                }
            }
        }
        Settings {
            SettingsView(wlanModel: wlanModel)
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
