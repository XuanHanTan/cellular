//
//  BluetoothModel.swift
//  Cellular
//
//  Created by Xuan Han on 7/6/23.
//

import Foundation
import CoreBluetooth
import HandySwift

extension Data {
    init?(fromHexEncodedString string: String) {
        // Convert 0 ... 9, a ... f, A ...F to their decimal value,
        // return nil for all other input characters
        func decodeNibble(u: UInt8) -> UInt8? {
            switch(u) {
            case 0x30 ... 0x39:
                return u - 0x30
            case 0x41 ... 0x46:
                return u - 0x41 + 10
            case 0x61 ... 0x66:
                return u - 0x61 + 10
            default:
                return nil
            }
        }

        self.init(capacity: string.utf8.count/2)
        
        var iter = string.utf8.makeIterator()
        while let c1 = iter.next() {
            guard
                let val1 = decodeNibble(u: c1),
                let c2 = iter.next(),
                let val2 = decodeNibble(u: c2)
            else { return nil }
            self.append(val1 << 4 + val2)
        }
    }
}

class BluetoothModel: NSObject, ObservableObject, CBPeripheralDelegate, CBPeripheralManagerDelegate {
    private var peripheralManager: CBPeripheralManager!
    private let defaults = UserDefaults.standard
    private var serviceUUID: CBUUID?
    private let commandCharacteristicUUID = CBUUID(string: "00000001-0000-1000-8000-00805f9b34fb")
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
        
        sharedKey = String(randomWithLength: 32, allowedCharactersType: .alphaNumeric)
        defaults.set(sharedKey!, forKey: "sharedKey")
        
        initializeBluetooth()
        
        return [
            "serviceUUID": serviceUUID!.uuidString,
            "sharedKey": sharedKey!,
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
            sharedKey = defaults.string(forKey: "sharedKey")
            
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
                                                             properties: [.notify, .write],
                                                             value: nil,
                                                             permissions: [.readable, .writeable])
        
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
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.value != nil else {
            print("Value is empty!")
            return
        }
        
        print("Central wrote value to characteristic \(characteristic.uuid.uuidString): \(String(bytes: characteristic.value!, encoding: .utf8) ?? "")")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for eachRequest in requests {
            guard let requestValue = eachRequest.value,
                  let stringFromData = String(data: requestValue, encoding: .utf8) else {
                peripheral.respond(to: eachRequest, withResult: .attributeNotFound)
                continue
            }
            
            let parts = stringFromData.split(separator: " ")
            
            guard !parts.isEmpty else {
                print("Error: No usable parts found for this request.")
                peripheral.respond(to: eachRequest, withResult: .attributeNotFound)
                continue
            }
            
            let command = parts[0]
            
            guard let ivData = Data(fromHexEncodedString: String(parts[1])) else {
                peripheral.respond(to: eachRequest, withResult: .attributeNotFound)
                continue
            }
            let aes = AES(key: sharedKey!, ivData: ivData)
            
            switch command {
                case "0":
                    let cipherText = parts[2]
                    if let decodedData = Data(base64Encoded: cipherText.data(using: .utf8)!) {
                        let plainText = aes!.decrypt(data: decodedData) ?? ""
                        let plainTextSplit = plainText.split(separator: " ")
                        let ssid = plainTextSplit[0]
                        let password = plainTextSplit[1]
                        saveHotspotInfo(ssid: String(ssid), password: String(password))
                    }
                default:
                    print("Error: Unrecognised command (\(command))")
            }
            
            peripheral.respond(to: eachRequest, withResult: .success)
        }
    }
    
    func disposeBluetooth() {
        peripheralManager.stopAdvertising()
        peripheralManager.removeAllServices()
    }
    
    private func saveHotspotInfo(ssid: String, password: String) {
        defaults.set(ssid, forKey: "ssid")
        defaults.set(password, forKey: "password")
        print("Saved hotspot info: \(ssid) \(password)")
    }
}
