//
//  BluetoothModel.swift
//  Cellular
//
//  Created by Xuan Han on 7/6/23.
//

import Foundation
import CoreBluetooth

class BluetoothModel: NSObject, ObservableObject, CBPeripheralDelegate, CBPeripheralManagerDelegate {
    private var peripheralManager: CBPeripheralManager!
    private let defaults = UserDefaults.standard
    private var serviceUUID: CBUUID?
    private let commandCharacteristicUUID = CBUUID(string: "4748240c-95d5-4a64-b425-6c24c36d0323")
    private var sharedKey: String?
    
    private var transferCharacteristic: CBMutableCharacteristic!
    
    var isPoweredOn = false
    @Published var isBluetoothOffDialogPresented = false
    @Published var isBluetoothNotGrantedDialogPresented = false
    var isBluetoothNotSupportedDialogPresented = false
    @Published var isBluetoothUnknownErrorDialogPresented = false

    func prepareForNewConnection() -> [String: String] {
        serviceUUID = CBUUID(nsuuid: UUID())
        defaults.set(serviceUUID!.uuidString, forKey: "serviceUUID")
        
        sharedKey = UUID().uuidString
        defaults.set(sharedKey!, forKey: "sharedPIN")
        
        initializeBluetooth()
        
        return [
            "serviceUUID": serviceUUID!.uuidString,
            "sharedPIN": sharedKey!,
        ]
    }
    
    func initializeBluetooth() {
        if serviceUUID == nil {
            guard let serviceUUIDString = defaults.string(forKey: "serviceUUID")
            else {
                print("Service UUID not set, call prepareForNewConnection() first.")
                return
            }
            
            serviceUUID = CBUUID(string: serviceUUIDString)
        }
        if sharedKey == nil {
            sharedKey = defaults.string(forKey: "sharedPIN")
            
            if sharedKey == nil {
                print("Shared PIN not set, call prepareForNewConnection() first.")
                return
            }
        }
        
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
            case .poweredOn:
                print("CBManager is powered on")
                isPoweredOn = true
                isBluetoothOffDialogPresented = false
                isBluetoothNotGrantedDialogPresented = false
                isBluetoothNotSupportedDialogPresented = false
                isBluetoothUnknownErrorDialogPresented = false
                setupPeripheral()
            case .poweredOff:
                print("CBManager is not powered on")
                isBluetoothOffDialogPresented = true
                return
            case .resetting:
                print("CBManager is resetting")
                isBluetoothUnknownErrorDialogPresented = true
                return
            case .unauthorized:
                print("Bluetooth permission was not granted")
                isBluetoothNotGrantedDialogPresented = true
                return
            case .unsupported:
                print("Bluetooth is not supported on this device")
                isBluetoothNotSupportedDialogPresented = true
                return
            default:
                print("A previously unknown peripheral manager state occurred")
                isBluetoothUnknownErrorDialogPresented = true
                return
        }
    }
    
    private func setupPeripheral() {
        // Start with the CBMutableCharacteristic.
        let transferCharacteristic = CBMutableCharacteristic(type: commandCharacteristicUUID,
                                                             properties: [.notify],
                                                             value: nil,
                                                             permissions: [.readable])
        
        // Create a service from the characteristic.
        let transferService = CBMutableService(type: serviceUUID!, primary: true)
        
        // Add the characteristic to the service.
        transferService.characteristics = [transferCharacteristic]
        
        // And add it to the peripheral manager.
        peripheralManager.add(transferService)
        
        // Save the characteristic for later.
        self.transferCharacteristic = transferCharacteristic
        
        peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [serviceUUID]])
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("Central subscribed to characteristic \(characteristic.uuid.uuidString)")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("Central unsubscribed from characteristic \(characteristic.uuid.uuidString)")
    }
    
    func disposeBluetooth() {
        peripheralManager.stopAdvertising()
    }
}
