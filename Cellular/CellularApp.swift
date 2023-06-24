//
//  CellularApp.swift
//  Cellular
//
//  Created by Xuan Han on 5/6/23.
//

import SwiftUI
import ServiceManagement

@main
struct CellularApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    enum Views {
        case start, downloadApp, qrCode, settingUp, finishSetup
    }
    
    @State private var currentView: Views = .start
    @StateObject private var bluetoothModel = BluetoothModel()
    
    func finishSetup() {
        NSApplication.shared.keyWindow?.close()
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
                        FinishSetupView(handlePreferencesButton: {
                            finishSetup()
                            if #available(macOS 13, *) {
                                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                            } else {
                                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                            }
                        }, handleFinishButton: {
                            finishSetup()
                            NSApp.hide(self)
                            NSApp.setActivationPolicy(.accessory)
                        })
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
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            }
        }.windowStyle(.hiddenTitleBar).commands {
            CommandGroup(replacing: CommandGroupPlacement.newItem) {
            }
        }
        Settings {
            if bluetoothModel.isSetupComplete {
                SettingsView()
            }
        }
    }
}
