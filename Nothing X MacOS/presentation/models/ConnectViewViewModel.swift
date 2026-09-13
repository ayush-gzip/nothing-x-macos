import Foundation
import SwiftUI

class ConnectViewViewModel: ObservableObject {
    @Published var isFailedToConnectPresented = false
    @Published var isBluetoothOn = false
    private let bluetoothService: BluetoothService
    private var failureObserver: NSObjectProtocol?

    init(bluetoothService: BluetoothService) {
        self.bluetoothService = bluetoothService
        failureObserver = NotificationCenter.default.addObserver(forName: Notification.Name(BluetoothNotifications.FAILED_TO_CONNECT.rawValue), object: nil, queue: .main) { [weak self] _ in
            self?.isFailedToConnectPresented = true
        }
    }

    deinit {
        if let failureObserver = failureObserver { NotificationCenter.default.removeObserver(failureObserver) }
    }

    func checkBluetoothStatus() { isBluetoothOn = bluetoothService.isBluetoothOn() }
}
