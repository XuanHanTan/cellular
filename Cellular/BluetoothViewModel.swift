//
//  BluetoothViewModel.swift
//  Cellular
//
//  Created by Xuan Han on 7/6/23.
//

import Foundation
import CoreBluetooth

class BluetoothViewModel: NSObject, ObservableObject, CBPeripheralDelegate, CBPeripheralManagerDelegate {
    var isPoweredOn = false
    private var peripheralManager: CBPeripheralManager!
    private let cellularServiceUUID = CBUUID(string: "c3b9b9e9-be4e-4abf-9200-770f88b59977")
    private let commandCharacteristicUUID = CBUUID(string: "4748240c-95d5-4a64-b425-6c24c36d0323")
    
    private var transferCharacteristic: CBMutableCharacteristic!
    
    func initializeBluetooth() {
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
            case .poweredOn:
                print("CBManager is powered on")
                setupPeripheral()
            case .poweredOff:
                print("CBManager is not powered on")
                return
            case .resetting:
                print("CBManager is resetting")
                return
            case .unauthorized:
                print("Bluetooth permission was not granted")
                return
            case .unsupported:
                print("Bluetooth is not supported on this device")
                return
            default:
                print("A previously unknown peripheral manager state occurred")
                // In a real app, you'd deal with yet unknown cases that might occur in the future
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
        let transferService = CBMutableService(type: cellularServiceUUID, primary: true)
        
        // Add the characteristic to the service.
        transferService.characteristics = [transferCharacteristic]
        
        // And add it to the peripheral manager.
        peripheralManager.add(transferService)
        
        // Save the characteristic for later.
        self.transferCharacteristic = transferCharacteristic
        
        peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [cellularServiceUUID]])
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("Central subscribed to characteristic \(characteristic.uuid.uuidString)")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("Central unsubscribed from characteristic \(characteristic.uuid.uuidString)")
    }
}
