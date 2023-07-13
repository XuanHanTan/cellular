//
//  BluetoothModel.swift
//  Cellular
//
//  Created by Xuan Han on 7/6/23.
//

import Foundation
import CoreBluetooth
import CoreWLAN
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
    private let cwWiFiClient = CWWiFiClient()
    private var peripheralManager: CBPeripheralManager!
    private let defaults = UserDefaults.standard
    private var serviceUUID: CBUUID?
    private let commandCharacteristicUUID = CBUUID(string: "00000001-0000-1000-8000-00805f9b34fb")
    private let notificationCharacteristicUUID = CBUUID(string: "00000002-0000-1000-8000-00805f9b34fb")
    private var sharedKey: String?
    private var centralUUID: UUID?
    private var connectedCentral: CBCentral?
    private var resendValueQueue: [String] = []
    private var ssid: String?
    private var password: String?
    private var notificationCharacteristic: CBMutableCharacteristic!
    private let acceptableNetworkTypes = ["-1", "GPRS", "E", "3G", "4G", "5G"]
    
    var isPoweredOn = false
    @Published var isBluetoothOffDialogPresented = false
    @Published var isBluetoothNotGrantedDialogPresented = false
    @Published var isBluetoothNotSupportedDialogPresented = false
    @Published var isBluetoothUnknownErrorDialogPresented = false
    
    @Published var isHelloWorldReceived = false
    @Published var isSetupComplete = false
    @Published var isDeviceConnected = false
    @Published var isConnectingToHotspot = false
    @Published var isConnectedToHotspot = false
    
    @Published var signalLevel = -1
    @Published var networkType = "-1"
    @Published var batteryLevel = -1
    
    enum NotificationType: String {
        case EnableHotspot = "0"
        case DisableHotspot = "1"
    }
    
    enum CommandType: String {
        case HelloWorld = "0"
        case ShareHotspotDetails = "1"
        case SharePhoneInfo = "2"
        case ConnectToHotspot = "3"
        case DisconnectFromHotspot = "4"
    }
    
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
        ssid = defaults.string(forKey: "ssid")
        password = defaults.string(forKey: "password")
        
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
                return
            case .poweredOff:
                print("CBManager is not powered on")
                isBluetoothOffDialogPresented = true
                isPoweredOn = false
                return
            case .resetting:
                print("CBManager is resetting")
                isBluetoothUnknownErrorDialogPresented = true
                isPoweredOn = false
                return
            case .unauthorized:
                print("Bluetooth permission was not granted")
                isBluetoothNotGrantedDialogPresented = true
                isPoweredOn = false
                return
            case .unsupported:
                print("Bluetooth is not supported on this device")
                isBluetoothNotSupportedDialogPresented = true
                isPoweredOn = false
                return
            default:
                print("A previously unknown peripheral manager state occurred")
                isBluetoothUnknownErrorDialogPresented = true
                isPoweredOn = false
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
        
        // Create the characteristics
        let commandCharacteristic = CBMutableCharacteristic(type: commandCharacteristicUUID,
                                                            properties: .write,
                                                            value: nil,
                                                            permissions: .writeable)
        let notificationCharacteristic = CBMutableCharacteristic(type: notificationCharacteristicUUID,
                                                                 properties: .indicate,
                                                                 value: nil,
                                                                 permissions: .readable)
        
        // Create a service for the characteristics
        let commandService = CBMutableService(type: serviceUUID!, primary: true)
        
        // Add the characteristics to the service
        commandService.characteristics = [commandCharacteristic, notificationCharacteristic]
        
        // Add the service to the peripheral manager.
        peripheralManager.add(commandService)
        
        // Save the notification characteristic for later
        self.notificationCharacteristic = notificationCharacteristic
        
        // Start advertising the service
        peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [serviceUUID]])
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        guard central.identifier == centralUUID else {
            print("Error: Unknown central subscribed to characteristic.")
            return
        }
        
        print("Central subscribed to characteristic \(characteristic.uuid.uuidString)")
        connectedCentral = central
        isDeviceConnected = true
        peripheralManager.stopAdvertising()
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        guard central.identifier == centralUUID else {
            print("Unknown central unsubscribed from characteristic.")
            return
        }
        
        print("Central unsubscribed from characteristic \(characteristic.uuid.uuidString)")
        connectedCentral = nil
        isDeviceConnected = false
        isConnectingToHotspot = false
        isConnectedToHotspot = false
        peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [serviceUUID]])
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        if let firstResendValue = resendValueQueue.first {
            peripheralManager.updateValue(firstResendValue.data(using: .utf8)!, for: notificationCharacteristic, onSubscribedCentrals: [connectedCentral!])
            resendValueQueue.removeFirst()
            print("Resending value \(firstResendValue) to central.")
        }
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
            let commandString = String(parts[0])
            
            // Ensure that command is within known range
            guard let commandInt = Int(commandString) else {
                print("Error: Command is not an integer.")
                peripheral.respond(to: eachRequest, withResult: .unlikelyError)
                continue
            }
            guard commandInt >= 0 && commandInt <= 4 else {
                print("Error: Command is not within the range 0 to 4.")
                peripheral.respond(to: eachRequest, withResult: .unlikelyError)
                continue
            }
            
            let command = CommandType(rawValue: commandString)
            var plainTextSplit: [String.SubSequence]?
            
            if command != CommandType.HelloWorld {
                // Check for known central
                guard eachRequest.central.identifier == centralUUID else {
                    print("Error: Request received from unknown central.")
                    peripheral.respond(to: eachRequest, withResult: .insufficientAuthorization)
                    continue
                }
                
                if command == CommandType.ShareHotspotDetails {
                    // Ensure that IV data is present
                    guard let ivData = Data(fromHexEncodedString: String(parts[1])) else {
                        print("Error: IV data is missing")
                        peripheral.respond(to: eachRequest, withResult: .attributeNotFound)
                        continue
                    }
                    
                    // Prepare for decryption of data using shared key and IV
                    let aes = AES(key: sharedKey!, ivData: ivData)
                    let cipherText = parts[2]
                    
                    guard let decodedData = Data(base64Encoded: cipherText.data(using: .utf8)!) else {
                        print("Error: Could not decode payload")
                        peripheral.respond(to: eachRequest, withResult: .attributeNotFound)
                        continue
                    }
                    let plainText = aes!.decrypt(data: decodedData) ?? ""
                    plainTextSplit = plainText.split(separator: " ")
                } else {
                    guard parts.count >= 2 else {
                        print("Error: Payload is invalid.")
                        peripheral.respond(to: eachRequest, withResult: .unlikelyError)
                        continue
                    }
                    
                    plainTextSplit = parts
                    plainTextSplit!.removeFirst()
                }
            }
            
            switch command {
                case .HelloWorld:
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
                case .ShareHotspotDetails:
                    // Ensure that plaintext has two parts
                    guard plainTextSplit!.count == 2 else {
                        print("Error: Payload is invalid.")
                        peripheral.respond(to: eachRequest, withResult: .unlikelyError)
                        continue
                    }
                    
                    // Split plaintext to SSID and password
                    let ssid = plainTextSplit![0]
                    let password = plainTextSplit![1]
                    
                    // Store hotspot info in UserDefaults
                    saveHotspotInfo(ssid: String(ssid), password: String(password))
                    
                    // Indicate successful BLE operation
                    peripheral.respond(to: eachRequest, withResult: .success)
                    
                    // Set setup to be complete if needed
                    if !isSetupComplete {
                        isSetupComplete = true
                        defaults.set(isSetupComplete, forKey: "isSetupComplete")
                    }
                case .SharePhoneInfo:
                    // Ensure that plaintext has three parts
                    guard plainTextSplit!.count == 3 else {
                        print("Error: Payload is invalid.")
                        peripheral.respond(to: eachRequest, withResult: .unlikelyError)
                        continue
                    }
                    
                    let networkType = String(plainTextSplit![1])
                    
                    // Split plaintext to signal level, network type and battery level
                    guard let signalLevel = Int(plainTextSplit![0]), let batteryLevel = Int(plainTextSplit![2]), signalLevel >= -1, signalLevel <= 3, batteryLevel >= -1, batteryLevel <= 100, (batteryLevel != -1 ? batteryLevel % 25 == 0: true), acceptableNetworkTypes.contains(networkType) else {
                        print("Error: Payload is invalid.")
                        peripheral.respond(to: eachRequest, withResult: .unlikelyError)
                        continue
                    }
                    
                    // Update UI with new phone info accordingly
                    setPhoneInfo(signalLevel: signalLevel, networkType: networkType, batteryLevel: batteryLevel)
                    
                    // Indicate successful BLE operation
                    peripheral.respond(to: eachRequest, withResult: .success)
                case .ConnectToHotspot:
                    // Connect to hotspot
                    connectToHotspot()
                case .DisconnectFromHotspot:
                    // Disconnect from hotspot
                    internalDisconnectFromHotspot()
                default:
                    print("Error: Unrecognised command")
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
        self.ssid = ssid
        self.password = password
        defaults.set(ssid, forKey: "ssid")
        defaults.set(password, forKey: "password")
        
        print("Saved hotspot info: \(ssid) \(password)")
    }
    
    private func setPhoneInfo(signalLevel: Int, networkType: String, batteryLevel: Int) {
        if signalLevel != -1 {
            self.signalLevel = signalLevel
        }
        if networkType != "-1" {
            self.networkType = networkType
        }
        if batteryLevel != -1 {
            self.batteryLevel = batteryLevel
        }
        
        print("Phone info set: \(signalLevel) \(networkType) \(batteryLevel)")
    }
    
    private func updateCharacteristicValue(value: String) {
        let status = peripheralManager.updateValue(value.data(using: .utf8)!, for: notificationCharacteristic, onSubscribedCentrals: [connectedCentral!])
        if status {
            print("Value \(value) sent successfully.")
        } else {
            resendValueQueue.append(value)
            print("Value \(value) send failed, adding to resend queue.")
        }
    }
    
    func enableHotspot() {
        guard isPoweredOn else {
            print("Error: Peripheral manager is not powered on.")
            return
        }
        
        guard connectedCentral != nil else {
            print("Error: Device must be connected to Android Companion.")
            return
        }
        
        isConnectingToHotspot = true
        updateCharacteristicValue(value: "0")
    }
    
    private func connectToHotspot() {
        guard ssid != nil else {
            print("Hotspot SSID must be set before calling this function.")
            return
        }
        guard password != nil else {
            print("Hotspot password must be set before calling this function.")
            return
        }
        
        let cwInterface = cwWiFiClient.interface()!
        do {
            var selNetwork: CWNetwork? = nil
            for network in try cwInterface.scanForNetworks(withName: nil) {
                if network.ssid == ssid {
                    selNetwork = network
                }
            }
            if selNetwork != nil {
                try cwInterface.associate(to: selNetwork!, password: password)
                isConnectedToHotspot = true
            }
        } catch {
            print(error.localizedDescription)
        }
        isConnectingToHotspot = false
    }
    
    private func internalDisconnectFromHotspot() {
        let cwInterface = cwWiFiClient.interface()!
        cwInterface.disassociate()
        isConnectedToHotspot = false
        isConnectingToHotspot = false
    }
    
    func userDisconnectFromHotspot() {
        updateCharacteristicValue(value: "1")
        internalDisconnectFromHotspot()
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
        connectedCentral = nil
        notificationCharacteristic = nil
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
