//
//  CellularApp.swift
//  Cellular
//
//  Created by Xuan Han on 5/6/23.
//

import SwiftUI
import MenuBarExtraAccess
import UserNotifications

let wlanModel = WLANModel()
let bluetoothModel = BluetoothModel()
var locationModel = {
    let locationModel = LocationModel()
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
        if success {
            print("Notification permission granted (main).")
        }
        
        locationModel.registerForAuthorizationChanges {
            if bluetoothModel.isSetupComplete {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["location"])
                bluetoothModel.initializeBluetooth()
            }
        } onError: {
            if bluetoothModel.isSetupComplete {
                showFailedToStartNotification(reason: .LocationPermissionNotGranted)
                
                // Disconnect device
                bluetoothModel.dispose()
            }
        }
    }
    return locationModel
}()
var isSleeping = false

enum FailedToStartReason {
    case BluetoothOff
    case BluetoothPermissionNotGranted
    case BluetoothNotSupported
    case LocationPermissionNotGranted
    case UnknownBluetoothError
}

func getShortDescriptionForFailedToStart(reason: FailedToStartReason) -> String {
    switch reason {
        case .BluetoothOff:
            return "Enable Bluetooth to use Cellular"
        case .BluetoothPermissionNotGranted:
            return "Bluetooth permission is not granted"
        case .BluetoothNotSupported:
            return "Bluetooth is not supported"
        case .LocationPermissionNotGranted:
            return "Location Services permission is not granted."
        case .UnknownBluetoothError:
            return "An unknown error occured"
    }
}

func getDescriptionForFailedToStart(reason: FailedToStartReason) -> String {
    switch reason {
        case .BluetoothPermissionNotGranted:
            return "The Bluetooth permission is required for Cellular to communicate with your Android device. Please grant it in System Settings."
        case .BluetoothNotSupported:
            return "Bluetooth is not supported on this Mac."
        case .LocationPermissionNotGranted:
            return "The Location Services permission is required for Cellular to get the connection state of Wi-Fi. Please grant it in System Settings."
        case .UnknownBluetoothError:
            return "Cellular has encountered an unknown error. Please wait while Cellular restarts."
        default:
            return ""
    }
}

func getIdentifierForFailedToStart(reason: FailedToStartReason) -> String {
    switch reason {
        case .BluetoothPermissionNotGranted, .BluetoothNotSupported, .UnknownBluetoothError:
            return "bluetooth"
        case .LocationPermissionNotGranted:
            return "location"
        default:
            return ""
    }
}

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

func showFailedToStartNotification(reason: FailedToStartReason) {
    let content = UNMutableNotificationContent()
    content.title = "Failed to start Cellular"
    content.subtitle = getDescriptionForFailedToStart(reason: reason)
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
    let request = UNNotificationRequest(identifier: getIdentifierForFailedToStart(reason: reason), content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request)
}

@main
struct CellularApp: App {
    @Environment(\.openWindow) private var openWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @State private var menuBarItemPresented = false
    @StateObject private var wlanModel = Cellular.wlanModel
    @StateObject private var bluetoothModel = Cellular.bluetoothModel
    @StateObject private var locationModel = Cellular.locationModel
    @State private var path = NavigationPath()
    @State private var isLocationPermissionDenied = false
    
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
            .onChange(of: locationModel.isLocationPermissionDenied) { isLocationPermissionDenied in
                self.isLocationPermissionDenied = isLocationPermissionDenied
            }
            .alert("Turn on Bluetooth", isPresented: $bluetoothModel.isBluetoothOffDialogPresented) {
            } message: {
                Text("You must leave Bluetooth on so Cellular can remain connected to your Android device.")
            }
            .alert("Grant the Bluetooth permission", isPresented: $bluetoothModel.isBluetoothNotGrantedDialogPresented) {
            } message: {
                Text(getDescriptionForFailedToStart(reason: .BluetoothPermissionNotGranted))
            }
            .alert("Bluetooth is unsupported", isPresented: $bluetoothModel.isBluetoothNotSupportedDialogPresented) {
            } message: {
                Text(getDescriptionForFailedToStart(reason: .BluetoothNotSupported))
            }
            .alert("An unknown error occurred", isPresented: $bluetoothModel.isBluetoothUnknownErrorDialogPresented) {
            } message: {
                Text(getDescriptionForFailedToStart(reason: .UnknownBluetoothError))
            }
            .alert("Grant the Location Services permission", isPresented: $isLocationPermissionDenied) {
            } message: {
                Text(getDescriptionForFailedToStart(reason: .LocationPermissionNotGranted))
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
                MenuBarContentView(bluetoothModel: bluetoothModel, locationModel: locationModel, isMenuBarItemPresented: $menuBarItemPresented)
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
