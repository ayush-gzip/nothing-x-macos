//
//  CRC16.swift
//  BluetoothTest
//
//  Created by Daniel on 2025/2/13.
//

//checksum
class CRC16 {
    
    static func crc16(buffer: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0xFFFF // Initialize CRC to 0xFFFF
        
        for byte in buffer {
            crc ^= UInt16(byte) // XOR byte into the CRC
            for _ in 0..<8 { // Process each bit
                if (crc & 0x0001) != 0 { // Check if the least significant bit is set
                    crc = (crc >> 1) ^ 0xA001 // Shift right and XOR with polynomial
                } else {
                    crc >>= 1 // Just shift right
                }
            }
        }
        
        return crc // Return the final CRC value
    }
    
}

// RFCOMM is a byte stream. One callback can contain part of a packet or several packets.
struct NothingPacket {
    let bytes: [UInt8]
    var command: UInt16 { UInt16(bytes[3]) | (UInt16(bytes[4]) << 8) }
    var operationID: UInt8 { bytes[7] }
    var payload: [UInt8] { Array(bytes[8..<(8 + Int(bytes[5]))]) }

    static func take(from buffer: inout [UInt8]) -> [NothingPacket] {
        var packets: [NothingPacket] = []
        while !buffer.isEmpty {
            guard buffer[0] == 0x55 else { buffer.removeFirst(); continue }
            guard buffer.count >= 8 else { break }
            guard buffer[6] == 0 else {
                buffer.removeFirst()
                continue
            }
            let size = 10 + Int(buffer[5])
            guard buffer.count >= size else { break }
            let bytes = Array(buffer.prefix(size))
            let receivedCRC = UInt16(bytes[size - 2]) | (UInt16(bytes[size - 1]) << 8)
            let packet = NothingPacket(bytes: bytes)
            guard receivedCRC == CRC16.crc16(buffer: Array(bytes.dropLast(2))) ||
                    receivedCRC == CRC16.crc16(buffer: packet.payload) else {
                buffer.removeFirst()
                continue
            }
            buffer.removeFirst(size)
            packets.append(packet)
        }
        return packets
    }

    // GATT notifications preserve packet boundaries. This headphone omits the optional CRC.
    static func notification(_ bytes: [UInt8]) -> NothingPacket? {
        guard bytes.count >= 8, bytes[0] == 0x55, bytes[6] == 0 else { return nil }
        let size = 8 + Int(bytes[5])
        guard bytes.count == size || bytes.count == size + 2 else { return nil }
        let packet = NothingPacket(bytes: bytes)
        if bytes.count == size + 2 {
            let crc = UInt16(bytes[size]) | (UInt16(bytes[size + 1]) << 8)
            guard crc == CRC16.crc16(buffer: Array(bytes.prefix(size))) ||
                    crc == CRC16.crc16(buffer: packet.payload) else { return nil }
        }
        return packet.hasValidPayload ? packet : nil
    }

    var hasValidPayload: Bool {
        switch command {
        case 57345, 57346, 16391:
            guard let count = payload.first else { return false }
            return payload.count >= 1 + Int(count) * 2
        case 57347, 16414: return payload.count >= 2
        case 16415, 16464, 16449: return !payload.isEmpty
        case 16398: return payload.count >= 3
        case 16408:
            guard let count = payload.first else { return false }
            return payload.count >= 1 + Int(count) * 4
        default: return true
        }
    }

    var headphoneBattery: (level: Int, charging: Bool)? {
        guard payload.count == 3, payload[2] & 0x7f <= 100 else { return nil }
        return (Int(payload[2] & 0x7f), payload[2] & 0x80 != 0)
    }
}
