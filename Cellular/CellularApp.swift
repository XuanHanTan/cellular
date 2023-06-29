//
//  CellularApp.swift
//  Cellular
//
//  Created by Xuan Han on 5/6/23.
//

import SwiftUI
import ServiceManagement
import MenuBarExtraAccess

@main
struct CellularApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    enum Views {
        case start, downloadApp, qrCode, settingUp, finishSetup
    }
    
    @State private var currentView: Views = .start
    @State private var menuBarItemPresented = false
    @StateObject private var bluetoothModel = BluetoothModel()
    
    func finishSetup() {
        // Close setup window
        NSApplication.shared.keyWindow?.close()
        
        // Make app an accessory (no icon in Dock)
        NSApp.setActivationPolicy(.accessory)
        
        // Register login item to auto-start app on startup
        do {
            try SMAppService.loginItem(identifier: "com.xuanhan.cellularhelper").register()
        } catch {
            print("Failed to register login item: \(error.localizedDescription)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            VStack {
                switch currentView {
                    case .start:
                        StartView(
                            handleNextButton: {
                                currentView = .downloadApp
                            }
                        )
                    case .downloadApp:
                        DownloadAppView(
                            handleBackButton: {
                                currentView = .start
                            },
                            handleNextButton: {
                                currentView = .qrCode
                            }
                        )
                    case .qrCode:
                        QRCodeView(
                            handleBackButton: {
                                currentView = .downloadApp
                                bluetoothModel.disposeBluetooth()
                            },
                            handleNextScreen: {
                                currentView = .settingUp
                            },
                            bluetoothModel: bluetoothModel
                        )
                    case .settingUp:
                        SettingUpView(
                            handleNextScreen: {
                                currentView = .finishSetup
                            },
                            bluetoothModel: bluetoothModel
                        )
                    case .finishSetup:
                        FinishSetupView(
                            handleSettingsButton: {
                                finishSetup()
                                
                                // Open settings window
                                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                            }, handleFinishButton: {
                                finishSetup()
                            }
                        )
                }
            }
            .frame(minWidth: 1000, idealWidth: 1100, maxWidth: 1200,
                   minHeight: 700, idealHeight: 900, maxHeight: 1100,
                   alignment: .center)
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
            }
        }.windowStyle(.hiddenTitleBar).commands {
            // Disable new window command in Menu Bar
            CommandGroup(replacing: CommandGroupPlacement.newItem) {
            }
        }
        Settings {
            if bluetoothModel.isSetupComplete {
                SettingsView()
            }
        }
        MenuBarExtra(
            content: {
                MenuBarContentView(bluetoothModel: bluetoothModel, isMenuBarItemPresented: $menuBarItemPresented)
            },
            label: {
                MenuBarIconView(bluetoothModel: bluetoothModel)
            }
        )
        .menuBarExtraStyle(.window)
        .menuBarExtraAccess(isPresented: $menuBarItemPresented)
    }
}
