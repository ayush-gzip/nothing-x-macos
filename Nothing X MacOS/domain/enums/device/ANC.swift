//
//  ANC.swift
//  BluetoothTest
//
//  Created by Daniel on 2025/2/13.
//

enum ANC : UInt8, Codable {
    
    case OFF = 0x05
    case TRANSPARENCY = 0x07
    case ON_LOW = 0x03
    case ON_HIGH = 0x01
    case ON_MID = 0x02
    case ADAPTIVE = 0x04
    
    static let cancellationLevels: [ANC] = [.ON_LOW, .ON_MID, .ON_HIGH, .ADAPTIVE]

    var isCancellation: Bool { Self.cancellationLevels.contains(self) }

    var title: String {
        switch self {
        case .ON_LOW: return "Low"
        case .ON_MID: return "Medium"
        case .ON_HIGH: return "High"
        case .ADAPTIVE: return "Adaptive"
        case .TRANSPARENCY: return "Ambient"
        case .OFF: return "Off"
        }
    }
}
