//
//  MainViewViewModel.swift
//  Nothing X MacOS
//
//  Created by Daniel on 2025/2/19.
//

import Foundation
import SwiftUI

class MainViewViewModel : ObservableObject {
    
    
    private let bluetoothService: BluetoothService
    
    private let fetchDataUseCase: FetchDataUseCaseProtocol
    private let disconnectDeviceUseCase: DisconnectDeviceUseCaseProtocol
    private let getSavedDevicesUseCase: GetSavedDevicesUseCaseProtocol
    
    private let jsonEncoder: JsonEncoder = JsonEncoder.shared
    private let nothingRepository: NothingRepository
    
    @Published var rightBattery: Double? = nil
    @Published var leftBattery: Double? = nil
    
    @Published var nothingDevice: NothingDeviceEntity?

    @Published var headphoneANC: ANC?
    @Published var headphoneEQ: EQProfiles?

    var usesHeadphoneLayout: Bool {
        (nothingDevice ?? nothingRepository.getSaved().first)?.isHeadphonePro == true
    }

    var menuBattery: Double? {
        if nothingDevice?.isHeadphonePro == true { return leftBattery }
        guard let leftBattery = leftBattery, let rightBattery = rightBattery else { return nil }
        return (leftBattery + rightBattery) / 2
    }

    @Published var eqProfiles: EQProfiles = .BALANCED
    @Published var navigationPath = NavigationPath()
    
    @Published var leftTripleTapAction: TripleTapGestureActions = .NO_EXTRA_ACTION
    @Published var rightTripleTapAction: TripleTapGestureActions = .SKIP_BACK
    @Published var leftTapAndHoldAction: TapAndHoldGestureActions = .NO_EXTRA_ACTION
    @Published var rightTapAndHoldAction: TapAndHoldGestureActions = .NOISE_CONTROL
    
    
    
    init(bluetoothService: BluetoothService, nothingRepository: NothingRepository, nothingService: NothingService) {
        
        self.bluetoothService = bluetoothService
        self.nothingRepository = nothingRepository
        self.fetchDataUseCase = FetchDataUseCase(service: nothingService)
        self.disconnectDeviceUseCase = DisconnectDeviceUseCase(nothingService: nothingService)
        self.getSavedDevicesUseCase = GetSavedDevicesUseCase(nothingRepository: nothingRepository)
 
        NotificationCenter.default.addObserver(forName: Notification.Name(BluetoothNotifications.SYSTEM_DEVICE_CONNECTED.rawValue), object: nil, queue: .main) { [weak self] notification in
            guard let self = self, !self.bluetoothService.isDeviceConnected(),
                  let connected = notification.object as? BluetoothDeviceEntity,
                  connected.isConnected,
                  let saved = self.nothingRepository.getSaved().first(where: {
                      $0.isHeadphonePro && $0.bluetoothDetails.mac == connected.mac
                  }) else { return }
            nothingService.connectToNothing(device: saved.bluetoothDetails)
        }

        NotificationCenter.default.addObserver(forName: Notification.Name(BluetoothNotifications.CLOSED_RFCOMM_CHANNEL.rawValue), object: nil, queue: .main) {
            notification in
                        
            self.headphoneANC = nil
            self.headphoneEQ = nil
            self.nothingDevice = nil
            self.leftBattery = nil
            self.rightBattery = nil
            
            withAnimation {
                if self.getSavedDevicesUseCase.getSaved().isEmpty {
                    self.navigationPath.append(Destination.discover)
                } else {
                    self.navigationPath.append(Destination.connect)
                }
            }
  
        }
        
        NotificationCenter.default.addObserver(forName: Notification.Name(BluetoothNotifications.OPENED_RFCOMM_CHANNEL.rawValue), object: nil, queue: .main) {
            notification in
            
            self.fetchDataUseCase.fetchData()
            self.navigationPath.append(Destination.home)
        }
        
        
        NotificationCenter.default.addObserver(forName: Notification.Name(DataNotifications.DATA_RECEIVED.rawValue), object: nil, queue: .main) { notification in
            guard self.nothingDevice?.isHeadphonePro == true,
                  let bytes = notification.userInfo?["data"] as? [UInt8] else { return }
            let packet = NothingPacket(bytes: bytes)
            switch packet.command {
            case 16414, 57347: self.headphoneANC = ANC(rawValue: packet.payload[1])
            case 16415, 16464:
                let value = packet.payload.count > 1 ? packet.payload[1] : packet.payload[0]
                self.headphoneEQ = EQProfiles(rawValue: value) ?? .OTHER
            default: break
            }
        }

        NotificationCenter.default.addObserver(forName: Notification.Name(RepositoryNotifications.CONFIGURATION_DELETED.rawValue), object: nil, queue: .main) {
            notification in
            
            self.disconnectDeviceUseCase.disconnectDevice()
            
            self.navigationPath.append(Destination.discover)
        }

        NotificationCenter.default.addObserver(forName: Notification.Name(DataNotifications.REPOSITORY_DATA_UPDATED.rawValue), object: nil, queue: .main) { notification in
            
#warning("if there is a device currently connected and you are trying to connect or discover another device at some point it might just snap to home screen")
//            if self.currentDestination == .connect || self.currentDestination == .discover {
//                self.currentDestination = .home
//            }
            if let device = notification.object as? NothingDeviceEntity {
                self.nothingDevice = device
                withAnimation {
                    self.eqProfiles = device.listeningMode
                    self.rightTripleTapAction = device.tripleTapGestureActionRight
                    self.leftTripleTapAction = device.tripleTapGestureActionLeft
                    self.rightTapAndHoldAction = device.tapAndHoldGestureActionRight
                    self.leftTapAndHoldAction = device.tapAndHoldGestureActionLeft
                }
                
                self.jsonEncoder.addOrUpdateDevice(device.toDTO())
                
                self.rightBattery = device.isRightConnected ? Double(device.rightBattery) : nil
                self.leftBattery = device.isLeftConnected ? Double(device.leftBattery) : nil
            }
        }
        
    
        // Check Bluetooth status and set the destination accordingly
        if !bluetoothService.isBluetoothOn() || !bluetoothService.isDeviceConnected() {
            let devices = nothingRepository.getSaved()
            if (devices.isEmpty) {
                navigationPath.append(Destination.discover)
            } else {
                navigationPath.append(Destination.connect)
            }
        }
        
        
    }
    
    func navigateToBluetoothIsOff() {
        navigationPath.append(Destination.bluetooth_off)
    }
    
    
}
