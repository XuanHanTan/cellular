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
import UserNotifications

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
    private let notificationCharacteristicUUID = CBUUID(string: "00000002-0000-1000-8000-00805f9b34fb")
    private var sharedKey: String?
    private var centralUUID: UUID?
    private var connectedCentral: CBCentral?
    private var resendValueQueue: [NotificationType] = []
    private var notificationCharacteristic: CBMutableCharacteristic!
    private var resetCompletionHandler: (() -> Void)?
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
    var isLowBattery = false
    private var isResetting = false
    private var isDisposing = false
    private var reset2: () -> Void = {}
    
    @Published var signalLevel = -1
    @Published var networkType = "-1"
    @Published var batteryLevel = -1
    
    enum NotificationType: String {
        case EnableHotspot = "0"
        case DisableHotspot = "1"
        case IndicateConnectedHotspot = "2"
        case EnableSeePhoneInfo = "3"
        case DisableSeePhoneInfo = "4"
        case IndicateReset = "5"
        case DisconnectDevice = "6"
    }
    
    enum CommandType: String {
        case HelloWorld = "0"
        case ShareHotspotDetails = "1"
        case SharePhoneInfo = "2"
        case ConnectToHotspot = "3"
        case DisconnectFromHotspot = "4"
        case IndicateReset = "5"
    }
    
    override init() {
        super.init()
        isSetupComplete = defaults.bool(forKey: "isSetupComplete")
    }
    
    /**
     This function generates and stores in UserDefaults a new service UUID and shared key for connecting to a new device. It then prepares the device for incoming BLE connections.
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
        
        if let ssid = defaults.string(forKey: "ssid"), let password = defaults.string(forKey: "password") {
            wlanModel.setHotspotDetails(ssid: ssid, password: password)
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
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["bluetooth"])
            setupPeripheral()
            return
        case .poweredOff:
            print("CBManager is not powered on")
            isBluetoothOffDialogPresented = true
            isPoweredOn = false
            peripheralManager.stopAdvertising()
            peripheralManager.removeAllServices()
            return
        case .resetting:
            print("CBManager is resetting")
            isBluetoothUnknownErrorDialogPresented = true
            isPoweredOn = false
            if bluetoothModel.isSetupComplete {
                showFailedToStartNotification(reason: .UnknownBluetoothError)
            }
            return
        case .unauthorized:
            print("Bluetooth permission was not granted")
            isBluetoothNotGrantedDialogPresented = true
            isPoweredOn = false
            if bluetoothModel.isSetupComplete {
                showFailedToStartNotification(reason: .BluetoothPermissionNotGranted)
            }
            return
        case .unsupported:
            print("Bluetooth is not supported on this device")
            isBluetoothNotSupportedDialogPresented = true
            isPoweredOn = false
            if bluetoothModel.isSetupComplete {
                showFailedToStartNotification(reason: .BluetoothNotSupported)
            }
            return
        default:
            print("A previously unknown peripheral manager state occurred")
            isBluetoothUnknownErrorDialogPresented = true
            isPoweredOn = false
            if bluetoothModel.isSetupComplete {
                showFailedToStartNotification(reason: .UnknownBluetoothError)
            }
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
        peripheralManagerIsReady(toUpdateSubscribers: peripheral)
        
        if isSetupComplete {
            // Enable seeing phone info if needed
            let seePhoneInfo = defaults.bool(forKey: "seePhoneInfo")
            if seePhoneInfo {
                enableSeePhoneInfo()
            }
            
            // Evaluate whether Wi-Fi connection-based functions need to be run
            let cwWiFiClient = CWWiFiClient.shared()
            let cwInterface = cwWiFiClient.interface()!
            wlanModel.linkDidChangeForWiFiInterface(withName: cwInterface.interfaceName ?? "")
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        guard central.identifier == centralUUID else {
            print("Unknown central unsubscribed from characteristic.")
            return
        }
        
        print("Central unsubscribed from characteristic \(characteristic.uuid.uuidString)")
        connectedCentral = nil
        isDeviceConnected = false
        
        if isResetting {
            // Complete reset if reset is in progress
            reset2()
        } else {
            // Indicate disconnected from hotspot
            if isConnectedToHotspot || isConnectingToHotspot {
                isConnectingToHotspot = false
                isConnectedToHotspot = false
            }
            
            if isDisposing {
                // Skip restarting advertising if disposing
                isDisposing = false
            } else {
                peripheralManager.removeAllServices()
                
                // Restart advertising so the phone can reconnect later
                setupPeripheral()
            }
        }
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        // Retry writing the first value in the resend queue to the notification characteristic if it exists
        if let firstResendValue = resendValueQueue.first {
            peripheralManager.updateValue(firstResendValue.rawValue.data(using: .utf8)!, for: notificationCharacteristic, onSubscribedCentrals: [connectedCentral!])
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
            guard commandInt >= 0 && commandInt <= 5 else {
                print("Error: Command is not within the range 0 to 5.")
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
                    plainTextSplit = plainText.split(separator: "\" \"")
                } else {
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
                
                // Split plaintext to SSID and password and trim leading/trailing quotation marks
                let ssid = plainTextSplit![0].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                let password = plainTextSplit![1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                
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
                guard let signalLevel = Int(plainTextSplit![0]), let batteryLevel = Int(plainTextSplit![2]), signalLevel >= -1, signalLevel <= 3, batteryLevel >= -1, batteryLevel <= 100, acceptableNetworkTypes.contains(networkType) else {
                    print("Error: Payload is invalid.")
                    peripheral.respond(to: eachRequest, withResult: .unlikelyError)
                    continue
                }
                
                // Update UI with new phone info accordingly
                setPhoneInfo(signalLevel: signalLevel, networkType: networkType, batteryLevel: batteryLevel)
                
                if batteryLevel != -1 {
                    // Evaluate if minimum battery reached
                    evalMinimumBattery(batteryLevel: batteryLevel)
                }
                
                // Indicate successful BLE operation
                peripheral.respond(to: eachRequest, withResult: .success)
            case .ConnectToHotspot:
                print("Connecting to hotspot...")
                // Connect to hotspot
                connectToHotspot()
                
                // Indicate successful BLE operation
                peripheral.respond(to: eachRequest, withResult: .success)
            case .DisconnectFromHotspot:
                print("Disconnecting from hotspot...")
                // Disconnect from hotspot
                disconnectFromHotspot(indicateOnly: true, userInitiated: true)
                
                // Indicate successful BLE operation
                peripheral.respond(to: eachRequest, withResult: .success)
            case .IndicateReset:
                print("Unlinking phone...")
                
                // Indicate successful BLE operation
                peripheral.respond(to: eachRequest, withResult: .success)
                
                // Unlink phone
                reset(indicateOnly: true)
                wlanModel.reset()
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
        wlanModel.setHotspotDetails(ssid: ssid, password: password)
        defaults.set(ssid, forKey: "ssid")
        defaults.set(password, forKey: "password")
        
        print("Saved hotspot info: \(ssid) \(password)")
    }
    
    /**
     This function updates the phone info UI with the provided signal level, network type and battery level.
     - parameter signalLevel: The signal level of the phone (0 to 3), -1 if unchanged
     - parameter networkType: The network type of the phone (must be present in `acceptableNetworkTypes`), "-1" if unchanged
     - parameter batteryLevel: The battery level of the phone (0 to 100), -1 if unchanged
     */
    private func setPhoneInfo(signalLevel: Int, networkType: String, batteryLevel: Int) {
        if signalLevel != -1 {
            self.signalLevel = signalLevel
        }
        if networkType != "-1" {
            self.networkType = networkType
        }
        if batteryLevel != -1 {
            self.batteryLevel = Int(floor(Double(batteryLevel + 12) / 25)) * 25
        }
        
        print("Phone info set: \(signalLevel) \(networkType) \(batteryLevel)")
    }
    
    /**
     This function decides if the phone's battery level is below the minimum battery level and disconnects from the hotspot if needed.
     - parameter batteryLevel: The battery level of the phone (0 to 100)
     */
    private func evalMinimumBattery(batteryLevel: Int) {
        let minimumBatteryLevel = defaults.integer(forKey: "minimumBatteryLevel")
        
        // Disconnect from hotspot if needed
        if !isLowBattery && batteryLevel < minimumBatteryLevel && (isConnectingToHotspot || isConnectedToHotspot) {
            disconnectFromHotspot()
            
            // Show notification to inform user that hotspot has disconnected due to low battery
            let content = UNMutableNotificationContent()
            content.title = "Hotspot turned off"
            content.subtitle = "Your phone's battery is below \(minimumBatteryLevel)%."
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
        
        isLowBattery = batteryLevel < minimumBatteryLevel
    }
    
    /**
     This function updates the value of the notification characteristic.
     - parameter value: The new value of the notification characteristic
     */
    private func updateCharacteristicValue(value: NotificationType) {
        guard isPoweredOn else {
            print("Error: Peripheral manager is not powered on.")
            return
        }
        
        guard connectedCentral != nil else {
            print("Device is not connected to the Android Companion. Value will be added to resend queue.")
            resendValueQueue.append(value)
            return
        }
        
        let status = peripheralManager.updateValue(value.rawValue.data(using: .utf8)!, for: notificationCharacteristic, onSubscribedCentrals: [connectedCentral!])
        if status {
            print("Value \(value) sent successfully.")
        } else {
            resendValueQueue.append(value)
            print("Value \(value) send failed, adding to resend queue.")
        }
    }
    
    /**
     This function enables the mobile hotspot.
     */
    func enableHotspot() {
        guard isPoweredOn else {
            print("Error: Peripheral manager is not powered on.")
            return
        }
        
        guard connectedCentral != nil else {
            print("Error: Device must be connected to Android Companion.")
            return
        }
        
        if !(isConnectingToHotspot || isConnectedToHotspot) {
            isConnectingToHotspot = true
            updateCharacteristicValue(value: .EnableHotspot)
        }
    }
    
    /**
     This function connects the device to the mobile hotspot.
     */
    private func connectToHotspot() {
        isConnectingToHotspot = true
        
        wlanModel.connect { [self] in
            isConnectedToHotspot = true
            isConnectingToHotspot = false
        } onError: { [self] in
            isConnectingToHotspot = false
            disconnectFromHotspot(systemControlling: false)
        }
    }
    
    /**
     This function notifies the phone that the device is connected to the mobile hotspot.
     */
    func notifyConnectedToHotspot() {
        guard isPoweredOn else {
            print("Error: Peripheral manager is not powered on.")
            return
        }
        
        guard connectedCentral != nil else {
            print("Error: Device must be connected to Android Companion.")
            return
        }
        
        guard isConnectedToHotspot != true else {
            print("Error: Device is already known to be connected to hotspot.")
            return
        }
        
        updateCharacteristicValue(value: .IndicateConnectedHotspot)
        
        isConnectedToHotspot = true
        isConnectingToHotspot = false
    }
    
    /**
     This function disconnects the device from the mobile hotspot.
     - parameter indicateOnly: Whether the Mac should only update itself that hotspot has been disconnected
     - parameter systemControlling: Whether this app should disconnect from Wi-Fi for the user
     - parameter userInitiated: Whether the user initiated this disconnection
     */
    func disconnectFromHotspot(indicateOnly: Bool = false, systemControlling: Bool = true, userInitiated: Bool = false) {
        if !indicateOnly {
            updateCharacteristicValue(value: .DisableHotspot)
        }
        
        wlanModel.disconnect(indicateOnly: indicateOnly, systemControlling: systemControlling, userInitiated: userInitiated)
        
        isConnectedToHotspot = false
        isConnectingToHotspot = false
    }
    
    /**
     This function enables the "See phone info" feature.
     */
    func enableSeePhoneInfo() {
        updateCharacteristicValue(value: .EnableSeePhoneInfo)
    }
    
    /**
     This function disables the "See phone info" feature.
     */
    func disableSeePhoneInfo() {
        updateCharacteristicValue(value: .DisableSeePhoneInfo)
        signalLevel = -1
        networkType = "-1"
        batteryLevel = -1
    }
    
    /**
     This function registers a reset completion handler that will be called when the device finishes resetting. This is typically used to update UI.
     */
    func registerResetCompletionHandler(resetCompletionHandler: @escaping () -> Void) {
        self.resetCompletionHandler = resetCompletionHandler
    }
    
    /**
     This function disconnects the device from the Android companion and de-initialises the peripheral manager. To re-initialise, call `initializeBluetooth()` again.
     */
    func dispose() {
        if isPoweredOn {
            // Prevent advertising from starting again
            isDisposing = true
            
            // De-initialise peripheral manager
            peripheralManager.stopAdvertising()
            peripheralManager.removeAllServices()
            peripheralManager.delegate = nil
            
            // Make peripheral manager believe that the phone has unsubscribed from the notification characteristic
            if isDeviceConnected {
                peripheralManager(peripheralManager, central: connectedCentral!, didUnsubscribeFrom: notificationCharacteristic)
            }
            
            isPoweredOn = false
            print("Disposed Bluetooth model successfully.")
        }
    }
    
    /**
     This function forgets the device paired to this Mac and prevents devices from connecting to it.
     - parameter indicateOnly: Whether the Mac should only update itself that reset has been initiated
     */
    func reset(indicateOnly: Bool = false) {
        isResetting = true
        
        reset2 = { [self] in
            // Stop advertising services
            peripheralManager.stopAdvertising()
            peripheralManager.removeAllServices()
            peripheralManager.delegate = nil
            
            // Reset all variables
            serviceUUID = nil
            sharedKey = nil
            centralUUID = nil
            connectedCentral = nil
            resendValueQueue.removeAll()
            isPoweredOn = false
            isBluetoothOffDialogPresented = false
            isBluetoothNotGrantedDialogPresented = false
            isBluetoothNotSupportedDialogPresented = false
            isBluetoothUnknownErrorDialogPresented = false
            isHelloWorldReceived = false
            isSetupComplete = false
            isDeviceConnected = false
            isConnectingToHotspot = false
            isConnectedToHotspot = false
            isLowBattery = false
            isResetting = false
            isDisposing = false
            signalLevel = -1
            networkType = "-1"
            batteryLevel = -1
            
            // Clear relevant User Defaults
            defaults.removeObject(forKey: "serviceUUID")
            defaults.removeObject(forKey: "sharedKey")
            defaults.removeObject(forKey: "centralUUID")
            defaults.removeObject(forKey: "isSetupComplete")
            defaults.removeObject(forKey: "ssid")
            defaults.removeObject(forKey: "password")
            
            // Get view to prepare for setup
            resetCompletionHandler?()
        }
        
        if isDeviceConnected {
            if (!indicateOnly) {
                updateCharacteristicValue(value: .IndicateReset)
            }
        } else {
            reset2()
        }
    }
}
