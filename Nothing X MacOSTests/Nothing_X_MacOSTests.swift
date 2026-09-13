import XCTest
@testable import Nothing_X_MacOS

final class Nothing_X_MacOSTests: XCTestCase {
    private func packet(_ command: UInt16, _ payload: [UInt8], payloadCRC: Bool = false) -> [UInt8] {
        var bytes: [UInt8] = [0x55, 0x60, 1, UInt8(command & 255), UInt8(command >> 8), UInt8(payload.count), 0, 7]
        bytes += payload
        let crc = CRC16.crc16(buffer: payloadCRC ? payload : bytes)
        return bytes + [UInt8(crc & 255), UInt8(crc >> 8)]
    }

    func testHeadphoneBatteryAndStreamValidation() {
        let battery = packet(0x4007, [1, 6, 0x80 | 73])
        var stream = Array(battery.prefix(6))
        XCTAssertTrue(NothingPacket.take(from: &stream).isEmpty)
        stream += battery.dropFirst(6)
        stream += packet(0x401e, [1, 7], payloadCRC: true)
        let packets = NothingPacket.take(from: &stream)
        XCTAssertEqual(packets.count, 2)
        XCTAssertTrue(stream.isEmpty)
        XCTAssertEqual(packets.first?.headphoneBattery?.level, 73)
        XCTAssertEqual(packets.first?.headphoneBattery?.charging, true)
        XCTAssertEqual(packets.last?.command, 0x401e)
        XCTAssertTrue(packets.allSatisfy(\.hasValidPayload))

        var corrupt = battery
        corrupt[10] ^= 1
        stream = [0, 1] + corrupt + battery
        XCTAssertEqual(NothingPacket.take(from: &stream).count, 1)
        XCTAssertFalse(NothingPacket(bytes: packet(0x4007, [2, 6, 73])).hasValidPayload)
        XCTAssertNil(NothingPacket(bytes: packet(0x4007, [1, 6, 127])).headphoneBattery)
        XCTAssertFalse(NothingPacket(bytes: packet(0x4018, [2, 2, 1, 3, 1])).hasValidPayload)
        XCTAssertFalse(NothingPacket(bytes: packet(0x401e, [1])).hasValidPayload)
    }

    func testObservedHeadphoneBLENotifications() {
        // Captured formats from CMF Headphone Pro firmware 1.0.1.49, without an application CRC.
        let battery: [UInt8] = [0x55, 0x60, 1, 7, 0x40, 3, 0, 3, 1, 6, 80]
        XCTAssertEqual(NothingPacket.notification(battery)?.headphoneBattery?.level, 80)
        XCTAssertNil(NothingPacket.notification(Array(battery.dropLast())))
        XCTAssertNil(NothingPacket.notification(battery + [0]))
        let anc: [UInt8] = [0x55, 0, 3, 3, 0xe0, 6, 0, 0, 1, 1, 0, 2, 1, 0]
        XCTAssertEqual(NothingPacket.notification(anc)?.command, 0xe003)
        XCTAssertEqual(NothingPacket.notification(anc)?.payload[1], ANC.ON_HIGH.rawValue)
        XCTAssertNotNil(NothingPacket.notification(packet(0x4007, [1, 6, 80])))
        var corrupt = packet(0x4007, [1, 6, 80])
        corrupt[10] ^= 1
        XCTAssertNil(NothingPacket.notification(corrupt))
    }

    func testDeviceIdentificationPreservesEar1() {
        let bluetooth = BluetoothDeviceEntity(name: "CMF Headphone Pro", mac: "00:11:22:33:44:55", channelId: 17, isPaired: true, isConnected: true)
        let headphone = NothingDeviceFDTO(bluetoothDetails: bluetooth)
        XCTAssertEqual(headphone.codename, .CMF_HEADPHONE_PRO)
        XCTAssertEqual(headphone.name, "CMF Headphone Pro")
        XCTAssertEqual(codenameFromSKU(sku: skuFromSerial(serial: "SHxx84")), .CMF_HEADPHONE_PRO)
        XCTAssertEqual(codenameFromSKU(sku: .CMF_HEADPHONE_PRO_LIGHT_GREEN_ALTERNATE), .CMF_HEADPHONE_PRO)
        XCTAssertEqual(codenameFromSKU(sku: .EAR_1_BLACK), .ONE)
        XCTAssertEqual(skuFromFirmware(firmware: "1.6700.1"), .EAR_1_WHITE)
        XCTAssertEqual(skuFromFirmware(firmware: ""), .UNKNOWN)
        XCTAssertEqual(skuFromSerial(serial: "SHxxZZ"), .UNKNOWN)
    }
    @MainActor
    func testMacOSConnectionOnlyReconnectsSavedHeadphones() {
        let details = BluetoothDeviceEntity(name: "CMF Headphone Pro", mac: "00:11:22:33:44:55", channelId: 15, isPaired: true, isConnected: true)
        let saved = NothingDeviceFDTO.toEntity(NothingDeviceFDTO(bluetoothDetails: details))
        let repository = ConnectionRepository(saved: [saved])
        let service = ConnectionService()
        let bluetooth = ConnectionBluetooth()
        let model = MainViewViewModel(bluetoothService: bluetooth, nothingRepository: repository, nothingService: service)
        XCTAssertTrue(service.connections.isEmpty, "Opening the app must not initiate a connection")
        func report(_ device: BluetoothDeviceEntity) {
            NotificationCenter.default.post(name: Notification.Name(BluetoothNotifications.SYSTEM_DEVICE_CONNECTED.rawValue), object: device)
        }
        let unrelated = BluetoothDeviceEntity(name: details.name, mac: "AA:BB:CC:DD:EE:FF", channelId: 15, isPaired: true, isConnected: true)
        report(unrelated)
        let disconnected = BluetoothDeviceEntity(name: details.name, mac: details.mac, channelId: 15, isPaired: true, isConnected: false)
        report(disconnected)
        XCTAssertTrue(service.connections.isEmpty)
        report(details)
        XCTAssertEqual(service.connections.map(\.mac), [details.mac])
        bluetooth.controlConnected = true
        report(details)
        XCTAssertEqual(service.connections.count, 1)
        withExtendedLifetime(model) {}
    }
}

private final class ConnectionBluetooth: BluetoothService {
    var controlConnected = false
    func isBluetoothOn() -> Bool { true }
    func isDeviceConnected() -> Bool { controlConnected }
}

private final class ConnectionRepository: NothingRepository {
    let saved: [NothingDeviceEntity]
    init(saved: [NothingDeviceEntity]) { self.saved = saved }
    func getSaved() -> [NothingDeviceEntity] { saved }
    func save(device: NothingDeviceEntity) {}
    func delete(device: NothingDeviceEntity) {}
    func contains(mac: String) -> Bool { saved.contains { $0.bluetoothDetails.mac == mac } }
    func delete(mac: String) {}
}

private final class ConnectionService: NothingService {
    var connections: [BluetoothDeviceEntity] = []
    func connectToNothing(device: BluetoothDeviceEntity) { connections.append(device) }
    func ringBuds() {}
    func stopRingingBuds() {}
    func switchANC(mode: ANC) {}
    func switchEQ(mode: EQProfiles) {}
    func fetchData() {}
    func discoverNothing() {}
    func stopNothingDiscovery() {}
    func isNothingConnected() -> BluetoothDeviceEntity? { nil }
    func isNothingConnected() -> Bool { false }
    func switchLowLatency(mode: Bool) {}
    func switchInEarDetection(mode: Bool) {}
    func switchGesture(device: DeviceType, gesture: GestureType, action: UInt8) {}
    func disconnect() {}
}
