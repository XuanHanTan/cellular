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

/**
 This class handles all things related to connecting to and communicating with the Cellular Companion app on the Android device.
 */
class BluetoothModel: NSObject, ObservableObject, CBPeripheralDelegate, CBPeripheralManagerDelegate {
    private var peripheralManager: CBPeripheralManager!
    private let defaults = UserDefaults.standard
    private var serviceUUID: CBUUID?
    private let commandCharacteristicUUID = CBUUID(string: "00000001-0000-1000-8000-00805f9b34fb")
    private var sharedKey: String?
    private var centralUUID: UUID?
    
    private var commandCharacteristic: CBMutableCharacteristic!
    
    var isPoweredOn = false
    @Published var isBluetoothOffDialogPresented = false
    @Published var isBluetoothNotGrantedDialogPresented = false
    var isBluetoothNotSupportedDialogPresented = false
    @Published var isBluetoothUnknownErrorDialogPresented = false
    
    @Published var isHelloWorldReceived = false
    @Published var isSetupComplete = false
    
    override init() {
        super.init()
        isSetupComplete = defaults.bool(forKey: "isSetupComplete")
    }
    
    /**
     This function generates and stores in UserDefaults a new service UUID and shared key for connecting to a new device.
     - Returns: A dictionary containing data to be added to a QR code for scanning by the Companion app
     */
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
    
    /**
     This function prepares this device for incoming BLE connections. The service UUID and shared key must be set or present in UserDefaults before this function is called.
     */
    func initializeBluetooth() {
        if serviceUUID == nil {
            guard let serviceUUIDString = defaults.string(forKey: "serviceUUID")
            else {
                print("Error: Service UUID not set, call prepareForNewConnection() first.")
                return
            }
            
            serviceUUID = CBUUID(string: serviceUUIDString)
        }
        if sharedKey == nil {
            sharedKey = defaults.string(forKey: "sharedKey")
            
            if sharedKey == nil {
                print("Error: Shared PIN not set, call prepareForNewConnection() first.")
                return
            }
        }
        if let centralUUIDString = defaults.string(forKey: "centralUUID") {
            centralUUID = UUID(uuidString: centralUUIDString)
        } else {
            if isSetupComplete {
                print("Error: Central UUID not set but setup is complete!")
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
    
    /**
     This function prepares the peripheral for advertisement of its services. Ensure that `peripheralManager` is powered on before this function is called.
     */
    private func setupPeripheral() {
        guard isPoweredOn else {
            print("Error: Peripheral manager is not powered on.")
            return
        }
        
        // Create the characteristic
        let commandCharacteristic = CBMutableCharacteristic(type: commandCharacteristicUUID,
                                                            properties: [.notify, .write],
                                                            value: nil,
                                                            permissions: [.readable, .writeable])
        
        // Create a service from the characteristic
        let commandService = CBMutableService(type: serviceUUID!, primary: true)
        
        // Add the characteristic to the service
        commandService.characteristics = [commandCharacteristic]
        
        // Add the service to the peripheral manager.
        peripheralManager.add(commandService)
        
        // Save the characteristic for later
        self.commandCharacteristic = commandCharacteristic
        
        // Start advertising the service
        peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [serviceUUID]])
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("Central subscribed to characteristic \(characteristic.uuid.uuidString)")
        // TODO: stop advertising
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("Central unsubscribed from characteristic \(characteristic.uuid.uuidString)")
        // TODO: start advertising
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
            // Ensure that request payload is present and decodable
            guard let requestValue = eachRequest.value,
                  let stringFromData = String(data: requestValue, encoding: .utf8),
                  stringFromData != "" else {
                print("Error: No usable payload found for this request.")
                peripheral.respond(to: eachRequest, withResult: .attributeNotFound)
                continue
            }
            
            // Split parts from request payload string
            let parts = stringFromData.split(separator: " ")
            let command = parts[0]
            
            // Check for known central if needed
            if command != "0" {
                guard eachRequest.central.identifier == centralUUID else {
                    print("Error: Request received from unknown central.")
                    peripheral.respond(to: eachRequest, withResult: .insufficientAuthorization)
                    continue
                }
            }
            
            switch command {
                    // Hello World command
                case "0":
                    // Ensure that the Hello World command is only received during setup
                    if !isSetupComplete {
                        print("Received Hello World")
                        isHelloWorldReceived = true
                        
                        // Store central UUID
                        centralUUID = eachRequest.central.identifier
                        defaults.setValue(centralUUID!.uuidString, forKey: "centralUUID")
                        
                        // Indicate successful BLE operation
                        peripheral.respond(to: eachRequest, withResult: .success)
                    } else {
                        print("Error: Setup has completed but Hello World is received.")
                        peripheral.respond(to: eachRequest, withResult: .requestNotSupported)
                    }
                case "1":
                    // Ensure that IV data is present
                    guard let ivData = Data(fromHexEncodedString: String(parts[1])) else {
                        peripheral.respond(to: eachRequest, withResult: .attributeNotFound)
                        continue
                    }
                    
                    // Prepare for decryption of data using shared key and IV
                    let aes = AES(key: sharedKey!, ivData: ivData)
                    let cipherText = parts[2]
                    
                    if let decodedData = Data(base64Encoded: cipherText.data(using: .utf8)!) {
                        let plainText = aes!.decrypt(data: decodedData) ?? ""
                        let plainTextSplit = plainText.split(separator: " ")
                        
                        // Ensure that plaintext has two parts
                        guard plainTextSplit.count == 2 else {
                            print("Error: Payload is invalid.")
                            peripheral.respond(to: eachRequest, withResult: .unlikelyError)
                            continue
                        }
                        
                        // Split plaintext to SSID and password
                        let ssid = plainTextSplit[0]
                        let password = plainTextSplit[1]
                        
                        // Store hotspot info in UserDefaults
                        saveHotspotInfo(ssid: String(ssid), password: String(password))
                        
                        // Indicate successful BLE operation
                        peripheral.respond(to: eachRequest, withResult: .success)
                        
                        // Set setup to be complete if needed
                        if !isSetupComplete {
                            isSetupComplete = true
                            defaults.set(isSetupComplete, forKey: "isSetupComplete")
                        }
                    } else {
                        print("Error: Could not decode payload")
                        peripheral.respond(to: eachRequest, withResult: .attributeNotFound)
                    }
                default:
                    print("Error: Unrecognised command (\(command))")
                    peripheral.respond(to: eachRequest, withResult: .attributeNotFound)
            }
        }
    }
    
    /**
     This function saves the provided hotspot SSID and password to UserDefaults.
     - parameter ssid: The SSID of the hotspot
     - parameter password: The password of the hotspot
     */
    private func saveHotspotInfo(ssid: String, password: String) {
        defaults.set(ssid, forKey: "ssid")
        defaults.set(password, forKey: "password")
        print("Saved hotspot info: \(ssid) \(password)")
    }
    
    /**
     This function forgets the device paired to this Mac and prevents devices from connecting to it.
     */
    func disposeBluetooth() {
        // Stop advertising services
        peripheralManager.stopAdvertising()
        peripheralManager.removeAllServices()
        
        // Forget stored values
        serviceUUID = nil
        sharedKey = nil
        centralUUID = nil
        isBluetoothOffDialogPresented = false
        isBluetoothNotGrantedDialogPresented = false
        isBluetoothNotSupportedDialogPresented = false
        isBluetoothUnknownErrorDialogPresented = false
        isHelloWorldReceived = false
        isSetupComplete = false
        
        defaults.removeObject(forKey: "serviceUUID")
        defaults.removeObject(forKey: "sharedKey")
        defaults.removeObject(forKey: "centralUUID")
        defaults.removeObject(forKey: "isSetupComplete")
    }
}
