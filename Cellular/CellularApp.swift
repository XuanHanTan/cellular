//
//  CellularApp.swift
//  Cellular
//
//  Created by Xuan Han on 5/6/23.
//

import SwiftUI

@main
struct CellularApp: App {
    enum Views {
    case start, downloadApp, qrCode
    }
    
    @State private var currentView: Views = .start
    @StateObject private var bluetoothModel = BluetoothModel()
    
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
                            },
                            bluetoothModel: bluetoothModel
                        )
                }
            }
            .frame(minWidth: 700, idealWidth: 900, maxWidth: 1100,
                    minHeight: 600, idealHeight: 800, maxHeight: 1000,
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
            }
        }.windowStyle(.hiddenTitleBar)
    }
}
