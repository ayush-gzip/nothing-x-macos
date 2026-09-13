import Foundation

class SettingsViewViewModel: ObservableObject {
    private let nothingService: NothingService
    @Published var shouldShowForgetDialog = false
    @Published var latencySwitch = false
    @Published var inEarSwitch = false
    @Published var name = ""
    @Published var mac = ""
    @Published var serial = ""
    @Published var firmware = ""
    @Published var isNothingDeviceAccessible = false

    init(nothingService: NothingService) { self.nothingService = nothingService }

    func showDevice(_ device: NothingDeviceEntity?, isAccessible: Bool) {
        name = device?.bluetoothDetails.name ?? ""
        mac = device?.bluetoothDetails.mac ?? ""
        serial = device?.serial ?? ""
        firmware = device?.firmware ?? ""
        latencySwitch = device?.isLowLatencyOn ?? false
        inEarSwitch = device?.isInEarDetectionOn ?? false
        isNothingDeviceAccessible = isAccessible
    }

    func switchLatency(mode: Bool) { nothingService.switchLowLatency(mode: mode) }
    func switchInEarDetection(mode: Bool) { nothingService.switchInEarDetection(mode: mode) }
}
