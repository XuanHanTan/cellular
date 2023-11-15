# Introduction

This document provides a brief overview of how Cellular works. You should read it before exploring the code. Cellular uses a MVVM (Model–view–viewmodel) architecture for the Android companion app, and a Model/View architecture for the macOS main app.

For the main app, the `BluetoothModel` controls incoming connections from the companion and sends notifications. The `WLANModel` controls the usage of Wi-Fi to connect and disconnect from hotspot, and scan for available networks. The `LocationModel` is just used to grant the Location Services permission.

For the companion app, the `BluetoothModel` initiates outgoing connections to the main app and receives notifications. There are view models for each view to manage the business logic of each view. The `BluetoothService` is a Service that runs all the time in the background to keep the Bluetooth connection alive and listens to signal, network type and battery changes on the phone.

# Important notes

Central = GATT Client

Peripheral = GATT Server

# Core functionality

Notes:

* The Mac is always the peripheral and the Android device is always the central (this is to bypass a limitation of Android devices not being able to advertise for longer than a set period).
* All user data sent should be encrypted with the shared PIN unless otherwise stated.
* All peripherals should advertise the encrypted "Hello world" message as a secondary form of verification besides the UUID/MAC address.
* There are two characteristics, the command and the notification characteristic. To send a command from the Android device to the Mac, the Android device writes to the command characteristic. To send a command from the Mac to the Android, the Mac writes to its notification characteristic. The Android device needs to be subscribed to notifications on the notification characteristic.

Command characteristic messages:

| **Message**             | **Number** |
| ----------------------- | ---------- |
| Hello world             | 0          |
| Sharing hotspot details | 1          |
| Sharing phone info      | 2          |
| Connect to hotspot      | 3          |
| Disconnect from hotspot | 4          |
| Unlink device           | 5          |

Notification characteristic messages:

| **Message**                        | **Number** |
| ---------------------------------- | ---------- |
| Enable hotspot                     | 0          |
| Disable hotspot                    | 1          |
| Indicate that hotspot is connected | 2          |
| Enable see phone info              | 3          |
| Disable see phone info             | 4          |
| Unlink device                      | 5          |
| Disconnect device                  | 6          |

### Linking to Android device

1. The Mac shows a QR code containing the randomised service UUID and a 6 digit PIN.
2. The Android device scans the QR code, connects to the Mac, and remembers the service UUID and shared PIN.
3. Bluetooth bonding is initiated (handled by system).
4. The Android device shares the "Hello world" command with the Mac and the Mac stores the UUID of the Android device. From then, the Mac will always ensure that the UUID of the Android device matches the stored UUID.
5. The Android device writes the hotspot SSID and password to the Mac's data characteristic (with command "Sharing hotspot details" attached).
6. If the Mac receives the data and decrypts it successfully, the Android device is considered linked.

### Retrieving phone information (every 1 min)

1. The Android device writes the network signal strength, mobile data network type and battery level to the Mac's command characteristic (with message "Sharing phone info" attached).

### Connecting to hotspot

1. The Mac sends an "Enable hotspot" message to the Android device by updating the value of the notification characteristic if the Mac initiates this connection.
2. The Android device turns on the mobile hotspot.
3. The Android device writes the "Connect to hotspot" command to the Mac's command characteristic.
4. The Mac receives the command and connects to the hotspot using the saved SSID and password.

### Disconnecting from hotspot

**If initiated on the Mac:**

1. The Mac sends a "Disconnect from hotspot" message to the Android device by updating the value of the notification characteristic.
2. The Android device turns off the mobile hotspot if the hotspot was turned on by Cellular.

**If initiated on the Android device:**

1. The Android device turns off the mobile hotspot if the hotspot was turned on by Cellular.
2. The Android device writes the "Disconnect from hotspot" command to the Mac's command characteristic.
3. The Mac disconnects from the hotspot.

### Unlinking the Android device

**If devices are connected:**

1. The Mac sends a "Unlink device" message to the Android device by updating the value of the notification characteristic, or the Android device writes the "Unlink device" message to the Mac's command characteristic.
2. The Android device disconnects from the Mac, including unsubscribing from notifications, un-bonding from the Mac and clearing the data store and variables.
3. When the Android device unsubscribes from the notification characteristic, the Mac changes the shared PIN and deletes the service UUID, stops advertising the service and clears all variables. However, settings are not cleared.

**If devices are disconnected:**

1. The Android device un-bonds from the Mac and clears the data store and variables.
2. The Mac changes the shared PIN and deletes the service UUID, stops advertising the service and clears all variables. However, settings are not cleared.
