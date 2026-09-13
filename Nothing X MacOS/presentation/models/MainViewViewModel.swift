import Foundation
import SwiftUI

class MainViewViewModel: ObservableObject {
    private let bluetoothService: BluetoothService
    private let nothingService: NothingService
    private let nothingRepository: NothingRepository
    private let selectionDefaults: UserDefaults
    private let notificationCenter: NotificationCenter
    private static let selectionKey = "selectedDeviceMAC"
    private var observers: [NSObjectProtocol] = []
    private var isChangingDevice = false

    @Published private(set) var savedDevices: [NothingDeviceEntity]
    @Published private(set) var selectedDeviceMAC: String?
    @Published private(set) var isSettingUpDevice = false
    @Published private(set) var isConnecting = false
    @Published var nothingDevice: NothingDeviceEntity?
    @Published var rightBattery: Double?
    @Published var leftBattery: Double?
    @Published var headphoneANC: ANC?
    @Published var headphoneEQ: EQProfiles?
    @Published var eqProfiles: EQProfiles = .BALANCED
    @Published var navigationPath = NavigationPath()
    @Published var leftTripleTapAction: TripleTapGestureActions = .NO_EXTRA_ACTION
    @Published var rightTripleTapAction: TripleTapGestureActions = .SKIP_BACK
    @Published var leftTapAndHoldAction: TapAndHoldGestureActions = .NO_EXTRA_ACTION
    @Published var rightTapAndHoldAction: TapAndHoldGestureActions = .NOISE_CONTROL

    var selectedDevice: NothingDeviceEntity? {
        savedDevices.first { $0.bluetoothDetails.mac == selectedDeviceMAC }
    }

    var usesHeadphoneLayout: Bool {
        !isSettingUpDevice && (nothingDevice ?? selectedDevice)?.isHeadphonePro == true
    }

    var menuBattery: Double? {
        if nothingDevice?.isHeadphonePro == true { return leftBattery }
        guard let leftBattery = leftBattery, let rightBattery = rightBattery else { return nil }
        return (leftBattery + rightBattery) / 2
    }

    init(bluetoothService: BluetoothService, nothingRepository: NothingRepository, nothingService: NothingService,
         selectionDefaults: UserDefaults = .standard, notificationCenter: NotificationCenter = .default) {
        self.bluetoothService = bluetoothService
        self.nothingRepository = nothingRepository
        self.nothingService = nothingService
        self.selectionDefaults = selectionDefaults
        self.notificationCenter = notificationCenter
        savedDevices = Self.sorted(nothingRepository.getSaved())
        let remembered = selectionDefaults.string(forKey: Self.selectionKey)
        selectedDeviceMAC = savedDevices.first { $0.bluetoothDetails.mac == remembered }?.bluetoothDetails.mac
            ?? savedDevices.first?.bluetoothDetails.mac
        rememberSelection()
        isSettingUpDevice = savedDevices.isEmpty

        observers.append(notificationCenter.addObserver(forName: Notification.Name(BluetoothNotifications.SYSTEM_DEVICE_CONNECTED.rawValue), object: nil, queue: .main) { [weak self] notification in
            guard let self = self, !self.isSettingUpDevice, !self.isConnecting,
                  !self.bluetoothService.isDeviceConnected(),
                  let connected = notification.object as? BluetoothDeviceEntity,
                  connected.isPaired, connected.isConnected, connected.mac == self.selectedDeviceMAC else { return }
            self.reconnectSelectedDevice()
        })
        observers.append(notificationCenter.addObserver(forName: Notification.Name(BluetoothNotifications.CLOSED_RFCOMM_CHANNEL.rawValue), object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.clearCurrentDevice()
            if !self.isChangingDevice { self.navigationPath = NavigationPath() }
        })
        observers.append(notificationCenter.addObserver(forName: Notification.Name(BluetoothNotifications.OPENED_RFCOMM_CHANNEL.rawValue), object: nil, queue: .main) { [weak self] _ in
            guard let self = self, self.nothingDevice?.bluetoothDetails.mac == self.selectedDeviceMAC else { return }
            self.isConnecting = false
            self.nothingService.fetchData()
            self.navigationPath = NavigationPath()
        })
        observers.append(notificationCenter.addObserver(forName: Notification.Name(BluetoothNotifications.FAILED_TO_CONNECT.rawValue), object: nil, queue: .main) { [weak self] _ in
            self?.isConnecting = false
        })
        observers.append(notificationCenter.addObserver(forName: Notification.Name(Notifications.REQUEST_RETRY.rawValue), object: nil, queue: .main) { [weak self] _ in
            self?.reconnectSelectedDevice()
        })
        observers.append(notificationCenter.addObserver(forName: Notification.Name(DataNotifications.DATA_RECEIVED.rawValue), object: nil, queue: .main) { [weak self] notification in
            guard let self = self, self.nothingDevice?.isHeadphonePro == true,
                  let bytes = notification.userInfo?["data"] as? [UInt8] else { return }
            let packet = NothingPacket(bytes: bytes)
            switch packet.command {
            case 16414, 57347:
                guard packet.payload.count >= 2 else { return }
                self.headphoneANC = ANC(rawValue: packet.payload[1])
            case 16415, 16464:
                guard let value = packet.payload.count > 1 ? packet.payload[1] : packet.payload.first else { return }
                self.headphoneEQ = EQProfiles(rawValue: value) ?? .OTHER
            default: break
            }
        })
        observers.append(notificationCenter.addObserver(forName: Notification.Name(DataNotifications.CONNECTED.rawValue), object: nil, queue: .main) { [weak self] notification in
            guard let self = self, self.isSettingUpDevice,
                  let device = notification.object as? NothingDeviceFDTO else { return }
            self.setSelection(device.bluetoothDetails.mac)
            self.isSettingUpDevice = false
            self.receiveDevice(NothingDeviceFDTO.toEntity(device))
        })
        observers.append(notificationCenter.addObserver(forName: Notification.Name(DataNotifications.REPOSITORY_DATA_UPDATED.rawValue), object: nil, queue: .main) { [weak self] notification in
            guard let device = notification.object as? NothingDeviceEntity else { return }
            self?.receiveDevice(device)
        })
        observers.append(notificationCenter.addObserver(forName: Notification.Name(RepositoryNotifications.CONFIGURATION_DELETED.rawValue), object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            guard let mac = (notification.object as? BluetoothDeviceEntity)?.mac ?? notification.object as? String else { return }
            self.savedDevices = Self.sorted(self.nothingRepository.getSaved())
            guard mac == self.selectedDeviceMAC else { return }
            self.closeCurrentControl()
            self.setSelection(self.savedDevices.first?.bluetoothDetails.mac)
            self.isSettingUpDevice = self.savedDevices.isEmpty
            self.navigationPath = NavigationPath()
        })
    }

    deinit { observers.forEach(notificationCenter.removeObserver) }

    func selectDevice(mac: String) {
        guard savedDevices.contains(where: { $0.bluetoothDetails.mac == mac }) else { return }
        if nothingDevice?.bluetoothDetails.mac == mac && bluetoothService.isDeviceConnected() {
            navigationPath = NavigationPath()
            return
        }
        closeCurrentControl()
        setSelection(mac)
        isSettingUpDevice = false
        navigationPath = NavigationPath()
        reconnectSelectedDevice()
    }

    func reconnectSelectedDevice() {
        guard !isConnecting, !isSettingUpDevice, let device = selectedDevice else { return }
        guard bluetoothService.isBluetoothOn() else { navigateToBluetoothIsOff(); return }
        isConnecting = true
        nothingService.connectToNothing(device: device.bluetoothDetails)
    }

    func startDeviceSetup() {
        closeCurrentControl()
        isSettingUpDevice = true
        navigationPath = NavigationPath()
    }

    func forgetSelectedDevice() {
        guard let device = selectedDevice else { return }
        nothingRepository.delete(device: device)
    }

    func navigateToBluetoothIsOff() {
        navigationPath = NavigationPath([Destination.bluetooth_off])
    }

    private func closeCurrentControl() {
        isChangingDevice = true
        nothingService.disconnect()
        clearCurrentDevice()
        isChangingDevice = false
    }

    private func clearCurrentDevice() {
        nothingDevice = nil
        headphoneANC = nil
        headphoneEQ = nil
        leftBattery = nil
        rightBattery = nil
        isConnecting = false
    }

    private func receiveDevice(_ device: NothingDeviceEntity) {
        guard !isSettingUpDevice, device.bluetoothDetails.mac == selectedDeviceMAC else { return }
        nothingRepository.save(device: device)
        savedDevices = Self.sorted(nothingRepository.getSaved())
        nothingDevice = device
        eqProfiles = device.listeningMode
        rightTripleTapAction = device.tripleTapGestureActionRight
        leftTripleTapAction = device.tripleTapGestureActionLeft
        rightTapAndHoldAction = device.tapAndHoldGestureActionRight
        leftTapAndHoldAction = device.tapAndHoldGestureActionLeft
        rightBattery = device.isRightConnected ? Double(device.rightBattery) : nil
        leftBattery = device.isLeftConnected ? Double(device.leftBattery) : nil
    }

    private func setSelection(_ mac: String?) {
        selectedDeviceMAC = mac
        rememberSelection()
    }

    private func rememberSelection() {
        selectionDefaults.set(selectedDeviceMAC, forKey: Self.selectionKey)
    }

    private static func sorted(_ devices: [NothingDeviceEntity]) -> [NothingDeviceEntity] {
        devices.sorted {
            if $0.bluetoothDetails.name == $1.bluetoothDetails.name { return $0.bluetoothDetails.mac < $1.bluetoothDetails.mac }
            return $0.bluetoothDetails.name.localizedStandardCompare($1.bluetoothDetails.name) == .orderedAscending
        }
    }
}
