import AppKit
import CoreBluetooth
import IOBluetooth
import Darwin

// Read-only check through the same service and connection code as the app.
@main
struct HeadphoneCheck {
    static func main() {
        setbuf(stdout, nil)
        _ = NSApplication.shared
        let service = NothingServiceImpl.shared
        let manager = BluetoothManager.shared
        var observers: [NSObjectProtocol] = []
        var readBattery = false
        var readFirmware = false
        var readSerial = false
        var readANC = false
        var readEQ = false
        observers.append(NotificationCenter.default.addObserver(forName: Notification.Name(BluetoothNotifications.BLUETOOTH_ON.rawValue), object: nil, queue: .main) { _ in connect(service) })
        observers.append(NotificationCenter.default.addObserver(forName: Notification.Name(BluetoothNotifications.OPENED_RFCOMM_CHANNEL.rawValue), object: nil, queue: .main) { _ in
            print("Control channel opened.")
            service.fetchData()
        })
        observers.append(NotificationCenter.default.addObserver(forName: Notification.Name(BluetoothNotifications.FAILED_TO_CONNECT.rawValue), object: nil, queue: .main) { _ in
            print("FAIL: Bluetooth control connection failed.")
            exit(1)
        })
        observers.append(NotificationCenter.default.addObserver(forName: Notification.Name(DataNotifications.DATA_RECEIVED.rawValue), object: nil, queue: .main) { notification in
            guard let bytes = notification.userInfo?["data"] as? [UInt8] else { return }
            let packet = NothingPacket(bytes: bytes)
            switch packet.command {
            case 16391, 57345, 57346: readBattery = packet.headphoneBattery != nil
            case 16450: readFirmware = !packet.payload.isEmpty
            case 16390: readSerial = !packet.payload.isEmpty
            case 16414, 57347: readANC = packet.payload.count >= 2 && ANC(rawValue: packet.payload[1]) != nil
            case 16415, 16464:
                let value = packet.payload.count > 1 ? packet.payload[1] : packet.payload.first
                readEQ = value.flatMap(EQProfiles.init(rawValue:)) != nil
            default: break
            }
            if readBattery && readFirmware && readSerial && readANC && readEQ {
                print("PASS: Headphone model, firmware, battery, ANC, and EQ read through the app service.")
                manager.disconnectDevice()
                exit(0)
            }
        })
        if manager.isBluetoothEnabled() { connect(service) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
            print("FAIL: Device check timed out. battery=\(readBattery), firmware=\(readFirmware), serial=\(readSerial), ANC=\(readANC), EQ=\(readEQ)")
            manager.disconnectDevice()
            exit(1)
        }
        withExtendedLifetime(observers) { CFRunLoopRun() }
    }
    private static func connect(_ service: NothingServiceImpl) {
        guard let device = (IOBluetoothDevice.pairedDevices() ?? [])
            .compactMap({ $0 as? IOBluetoothDevice })
            .first(where: { $0.name?.lowercased() == "cmf headphone pro" && $0.isConnected() }) else {
            print("FAIL: CMF Headphone Pro is not connected to this Mac.")
            exit(1)
        }
        service.connectToNothing(address: device.addressString)
    }
}
