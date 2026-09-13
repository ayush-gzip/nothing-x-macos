//
//  BluetoothManager.swift
//  BluetoothTest
//
//  Created by Daniel on 2025/2/13.
//

import Foundation
import IOBluetooth
import CoreBluetooth


class BluetoothManager: NSObject, IOBluetoothDeviceInquiryDelegate, IOBluetoothRFCOMMChannelDelegate, CBCentralManagerDelegate, CBPeripheralDelegate {

    static let shared = BluetoothManager()

    private var systemConnectedAddresses = Set<String>()
    private var systemDisconnectNotifications: [String: IOBluetoothUserNotification] = [:]
    private var systemConnectionNotification: IOBluetoothUserNotification?
    private var device: IOBluetoothDevice?
    private var channel: IOBluetoothRFCOMMChannel?
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private let headphoneServiceUUID = CBUUID(string: "FD90")
    private var deviceInquiry: IOBluetoothDeviceInquiry?
    private var connectionAttempt: UUID?
    private var receiveBuffer: [UInt8] = []
    private var controlChannelID: UInt8 = 15
    private var centralManager: CBCentralManager!
    private var deviceClass: UInt32? = nil
    private var bluetoothState: BluetoothStates = .OFF
    

    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        // macOS reports existing connections when the observer is registered.
        for device in (IOBluetoothDevice.pairedDevices() ?? []).compactMap({ $0 as? IOBluetoothDevice }) where device.isConnected() {
            systemConnectedAddresses.insert(device.addressString)
            observeSystemDisconnect(device)
        }
        systemConnectionNotification = IOBluetoothDevice.register(forConnectNotifications: self,
            selector: #selector(systemDeviceConnected(_:device:)))
    }
    
    
    @objc private func systemDeviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        guard device.isPaired(), device.isConnected() else { return }
        let details = BluetoothDeviceEntity(name: device.name ?? "Unknown", mac: device.addressString,
                                            channelId: 15, isPaired: true, isConnected: true)
        DispatchQueue.main.async {
            guard self.systemConnectedAddresses.insert(details.mac).inserted else { return }
            self.observeSystemDisconnect(device)
            NotificationCenter.default.post(name: Notification.Name(BluetoothNotifications.SYSTEM_DEVICE_CONNECTED.rawValue),
                                            object: details)
        }
    }

    private func observeSystemDisconnect(_ device: IOBluetoothDevice) {
        guard systemDisconnectNotifications[device.addressString] == nil else { return }
        systemDisconnectNotifications[device.addressString] = device.register(forDisconnectNotification: self,
            selector: #selector(systemDeviceDisconnected(_:device:)))
    }

    @objc private func systemDeviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        DispatchQueue.main.async {
            self.systemConnectedAddresses.remove(device.addressString)
            self.systemDisconnectNotifications.removeValue(forKey: device.addressString)?.unregister()
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            bluetoothState = .ON
            print("Bluetooth is ON")
            NotificationCenter.default.post(name: Notification.Name(BluetoothNotifications.BLUETOOTH_ON.rawValue), object: nil)
            
        case .poweredOff:
            bluetoothState = .OFF
            print("Bluetooth is OFF")
            NotificationCenter.default.post(name: Notification.Name(BluetoothNotifications.BLUETOOTH_OFF.rawValue), object: nil)
        case .resetting:
            print("Bluetooth is resetting")
        case .unauthorized:
            print("Bluetooth is unauthorized")
        case .unsupported:
            print("Bluetooth is unsupported")
        case .unknown:
            print("Bluetooth state is unknown")
        @unknown default:
            print("A previously unknown state occurred")
        }
    }
    
    func isBluetoothEnabled() -> Bool {
        return centralManager.state == .poweredOn
    }
    
    func isDeviceConnected() -> Bool {
        
        return (channel?.isOpen() ?? false) || (peripheral?.state == .connected && notifyCharacteristic?.isNotifying == true)
    }

    func getPaired(withClass: Int) -> [BluetoothDeviceEntity] {
        return IOBluetoothDevice.pairedDevices()
            .compactMap { $0 as? IOBluetoothDevice } // Safely unwrap and cast to IOBluetoothDevice
            .filter { $0.classOfDevice == withClass } // Filter by the specified device class
            .map { device in
                // Create an instance of BluetoothDevice
                BluetoothDeviceEntity(
                    name: device.name ?? "Unknown",
                    mac: device.addressString,
                    channelId: 15, // Set channelId as needed; using 0 as a placeholder
                    isPaired: true, // Assuming these devices are paired
                    isConnected: device.isConnected()
                )
            }
    }

        
    func startDeviceInquiry(withClass: UInt32) {
        if deviceInquiry == nil {
            
            deviceInquiry = IOBluetoothDeviceInquiry(delegate: self)
            deviceInquiry?.start()
            deviceClass = withClass
            print("Looking for devices")
            NotificationCenter.default.post(name: Notification.Name(BluetoothNotifications.SEARCHING.rawValue), object: nil)
        }
    }
    
    
    func deviceInquiryComplete(_ sender: IOBluetoothDeviceInquiry!, error: IOReturn, aborted: Bool) {
        deviceInquiry = nil
        print("Device inquiry complete.")
        deviceClass = nil
        NotificationCenter.default.post(name: Notification.Name(BluetoothNotifications.SEARCHING_COMPLETE.rawValue), object: nil)
    }
    
    func deviceInquiryDeviceFound(_ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!) {
        
        print("inquiry called")
    
        if (device.classOfDevice == deviceClass) {
            
            let bluetoothDevice = BluetoothDeviceEntity(name: device.name, mac: device.addressString, channelId: 15, isPaired: false, isConnected: false)
           
            NotificationCenter.default.post(name: Notification.Name(BluetoothNotifications.FOUND.rawValue), object: bluetoothDevice)
        }
        
    }
    
    
    
    func connectToDevice(address: String, channelID: UInt8) {
        stopDeviceInquiry()
        guard connectionAttempt == nil else { return }
        if isDeviceConnected() {
            guard device?.addressString == address else { return }
            NotificationCenter.default.post(name: Notification.Name(BluetoothNotifications.OPENED_RFCOMM_CHANNEL.rawValue), object: nil)
            return
        }
        guard let device = IOBluetoothDevice(addressString: address) else {
            connectionFailed()
            return
        }
        self.device = device
        controlChannelID = channelID
        receiveBuffer.removeAll()
        let attempt = UUID()
        connectionAttempt = attempt
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            if self.connectionAttempt == attempt { self.connectionFailed() }
        }
        if device.name?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "cmf headphone pro" {
            connectHeadphoneBLE()
        } else if device.performSDPQuery(self) != kIOReturnSuccess {
            connectionFailed()
        }
    }

    private func connectHeadphoneBLE() {
        guard centralManager.state == .poweredOn else { connectionFailed(); return }
        controlChannelID = 0
        let devices = centralManager.retrieveConnectedPeripherals(withServices: [headphoneServiceUUID, CBUUID(string: "FE2C")])
            .filter { $0.name?.lowercased() == "cmf headphone pro" }
        guard devices.count <= 1 else { connectionFailed(); return }
        if let peripheral = devices.first {
            connectBLE(peripheral)
        } else {
            centralManager.scanForPeripherals(withServices: [headphoneServiceUUID, CBUUID(string: "FE2C")])
        }
    }

    private func connectBLE(_ peripheral: CBPeripheral) {
        centralManager.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
        guard connectionAttempt != nil, self.peripheral == nil, name?.lowercased() == "cmf headphone pro" else { return }
        connectBLE(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard peripheral == self.peripheral else { return }
        peripheral.discoverServices([headphoneServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard peripheral == self.peripheral else { return }
        connectionFailed()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard peripheral == self.peripheral else { return }
        self.peripheral = nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
        device = nil
        connectionAttempt = nil
        NotificationCenter.default.post(name: Notification.Name(BluetoothNotifications.CLOSED_RFCOMM_CHANNEL.rawValue), object: nil)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard peripheral == self.peripheral else { return }
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == headphoneServiceUUID }) else {
            connectionFailed()
            return
        }
        peripheral.discoverCharacteristics(nil, for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard peripheral == self.peripheral else { return }
        guard error == nil,
              let write = service.characteristics?.first(where: { $0.uuid == CBUUID(string: "68745353-1810-4B13-83A2-C1B21B652C9B") && $0.properties.contains(.write) }),
              let notify = service.characteristics?.first(where: { $0.uuid == CBUUID(string: "CA235943-1810-45E6-8326-FC8CA3BC45CE") && $0.properties.contains(.notify) }) else {
            connectionFailed()
            return
        }
        writeCharacteristic = write
        notifyCharacteristic = notify
        peripheral.setNotifyValue(true, for: notify)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral == self.peripheral, characteristic == notifyCharacteristic else { return }
        guard error == nil, characteristic.isNotifying else { connectionFailed(); return }
        print("Nothing BLE control service ready.")
        connectionSucceeded()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral == self.peripheral, characteristic == notifyCharacteristic, error == nil,
              let data = characteristic.value, let packet = NothingPacket.notification(Array(data)) else { return }
        NotificationCenter.default.post(name: Notification.Name(DataNotifications.DATA_RECEIVED.rawValue),
                                        object: nil, userInfo: ["data": packet.bytes])
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral == self.peripheral, error != nil else { return }
        connectionFailed()
    }

    private func controlService(on device: IOBluetoothDevice) -> IOBluetoothSDPServiceRecord? {
        let bytes: [UInt8] = [0xdf, 0x21, 0xfe, 0x2c, 0x25, 0x15, 0x4f, 0xdb,
                             0x88, 0x86, 0xf1, 0x2c, 0x4d, 0x67, 0x92, 0x7c]
        let uuid = IOBluetoothSDPUUID(data: Data(bytes))
        return device.getServiceRecord(for: uuid)
    }

    @objc func sdpQueryComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        guard connectionAttempt != nil, device == self.device else { return }
        if status == kIOReturnSuccess { openControlChannel(on: device) }
        else { connectionFailed() }
    }

    private func openControlChannel(on device: IOBluetoothDevice) {
        if let service = controlService(on: device) {
            guard service.getRFCOMMChannelID(&controlChannelID) == kIOReturnSuccess else {
                connectionFailed()
                return
            }
        } else if device.name?.lowercased() == "cmf headphone pro" {
            // A missing service is an error; do not send commands to an unrelated channel.
            connectionFailed()
            return
        }
        print("Opening Nothing control channel \(controlChannelID)")
        let status = device.openRFCOMMChannelAsync(&channel, withChannelID: controlChannelID, delegate: self)
        if status != kIOReturnSuccess { connectionFailed() }
    }

    func rfcommChannelOpenComplete(_ channel: IOBluetoothRFCOMMChannel!, status: IOReturn) {
        guard connectionAttempt != nil, channel == self.channel else { channel?.close(); return }
        guard status == kIOReturnSuccess, let device = device else {
            connectionFailed()
            return
        }
        connectionSucceeded()
    }

    private func connectionSucceeded() {
        guard connectionAttempt != nil, let device = device else { return }
        connectionAttempt = nil
        let details = BluetoothDeviceEntity(name: device.name ?? "Unknown", mac: device.addressString,
                                            channelId: controlChannelID, isPaired: true, isConnected: true)
        NotificationCenter.default.post(name: Notification.Name(BluetoothNotifications.CONNECTED.rawValue), object: details)
        NotificationCenter.default.post(name: Notification.Name(BluetoothNotifications.OPENED_RFCOMM_CHANNEL.rawValue), object: nil)
    }

    private func connectionFailed() {
        let wasConnected = connectionAttempt == nil && isDeviceConnected()
        print("Nothing control connection failed or timed out.")
        connectionAttempt = nil
        centralManager.stopScan()
        let oldPeripheral = peripheral
        peripheral = nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
        if let oldPeripheral = oldPeripheral { centralManager.cancelPeripheralConnection(oldPeripheral) }
        let oldChannel = channel
        channel = nil
        device = nil
        receiveBuffer.removeAll()
        oldChannel?.close()
        if wasConnected {
            NotificationCenter.default.post(name: Notification.Name(BluetoothNotifications.CLOSED_RFCOMM_CHANNEL.rawValue), object: nil)
        }
        NotificationCenter.default.post(name: Notification.Name(BluetoothNotifications.FAILED_TO_CONNECT.rawValue), object: nil)
        NotificationCenter.default.post(name: Notification.Name(BluetoothNotifications.FAILED_RFCOMM_CHANNEL.rawValue), object: nil)
    }

    func send(data: UnsafeMutableRawPointer!, length: UInt16) {
        if let peripheral = peripheral, let write = writeCharacteristic {
            guard Int(length) <= peripheral.maximumWriteValueLength(for: .withResponse) else { connectionFailed(); return }
            peripheral.writeValue(Data(bytes: data, count: Int(length)), for: write, type: .withResponse)
        } else {
            channel?.writeSync(data, length: length)
        }
    }
    
    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        
        guard rfcommChannel == channel else { return }
        let bytes = Array(Data(bytes: dataPointer, count: dataLength))
        DispatchQueue.main.async {
            guard rfcommChannel == self.channel else { return }
            self.receiveBuffer.append(contentsOf: bytes)
            for packet in NothingPacket.take(from: &self.receiveBuffer) where packet.hasValidPayload {
                NotificationCenter.default.post(name: Notification.Name(DataNotifications.DATA_RECEIVED.rawValue),
                                                object: nil, userInfo: ["data": packet.bytes])
            }
        }
    }

    func rfcommChannelClosed(_ channel: IOBluetoothRFCOMMChannel) {
        guard channel == self.channel else { return }
        self.channel = nil
        self.device = nil
        connectionAttempt = nil
        receiveBuffer.removeAll()
        NotificationCenter.default.post(name: Notification.Name(BluetoothNotifications.CLOSED_RFCOMM_CHANNEL.rawValue), object: nil)
    }

    func disconnectDevice() {
        connectionAttempt = nil
        centralManager.stopScan()
        let oldPeripheral = peripheral
        peripheral = nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
        if let oldPeripheral = oldPeripheral { centralManager.cancelPeripheralConnection(oldPeripheral) }
        let oldChannel = channel
        channel = nil
        device = nil
        receiveBuffer.removeAll()
        oldChannel?.close()
        stopDeviceInquiry()
        NotificationCenter.default.post(name: Notification.Name(BluetoothNotifications.CLOSED_RFCOMM_CHANNEL.rawValue), object: nil)
        NotificationCenter.default.post(name: Notification.Name(BluetoothNotifications.DISCONNECTED.rawValue), object: nil)
    }

    func stopDeviceInquiry() {
        deviceInquiry?.stop()
    }

   
}
