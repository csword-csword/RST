import Foundation

/// Parses the MOKO "Customized – Sensor info" BLE advertisement frame used by
/// the MK Sensor series (the M1Pro on our weight pin).
///
/// The frame is broadcast as Service Data under 16-bit UUID `0xEA01`. iOS hands
/// us the bytes *after* the UUID via `CBAdvertisementDataServiceDataKey`, so the
/// payload begins at the frame-type byte:
///
/// Multi-byte fields are **big-endian** (MSB first), per the MOKO data-format
/// spec (e.g. temperature `0x00C8` → 200 → 20.0 °C; accel X `0x0028` → 40 mg).
///
/// ```
/// [0]      Frame type (0x80 = Sensor info)
/// [1]      Sensor status bitfield
/// [2..3]   Hall trigger count   (UInt16 BE)
/// [4..5]   Motion trigger count (UInt16 BE) — +1 per motion-trigger cycle
/// [6..7]   Accel X (mg)         (Int16  BE, signed)
/// [8..9]   Accel Y (mg)         (Int16  BE, signed)
/// [10..11] Accel Z (mg)         (Int16  BE, signed)
/// [12..13] Temperature          (Int16  BE, 0.1 °C/digit)   — optional
/// [14..15] Humidity             (UInt16 BE, 0.1 %RH/digit)  — optional
/// [16..17] Battery              (UInt16 BE: >100 = mV, else %)
/// [18..23] Tag ID (up to 6 bytes)
/// ```
///
/// Source: MOKO MK Sensor "Customized – Sensor info" advertisement data format.
struct PinSensorFrame: Equatable {
    static let frameType: UInt8 = 0x80

    var motionActive: Bool       // status bit1: device is moving
    var motionEquipped: Bool     // status bit2: accelerometer present
    var magnetCount: Int
    var motionCount: Int
    var accelX: Int              // mg, signed
    var accelY: Int
    var accelZ: Int
    var temperatureC: Double?
    var humidity: Double?
    var batteryMilliVolts: Int?
    var batteryPercent: Int?
    var tagID: String

    /// Acceleration vector magnitude in g (gravity ≈ 1.0).
    var magnitudeG: Double {
        let x = Double(accelX), y = Double(accelY), z = Double(accelZ)
        return (x * x + y * y + z * z).squareRoot() / 1000.0
    }

    init?(serviceData data: Data) {
        let b = [UInt8](data)
        // Need at least through the accelerometer triplet.
        guard b.count >= 12, b[0] == Self.frameType else { return nil }

        // Big-endian: the first byte is the most significant.
        func u16(_ i: Int) -> Int { (Int(b[i]) << 8) | Int(b[i + 1]) }
        func s16(_ i: Int) -> Int { Int(Int16(bitPattern: UInt16(u16(i)))) }

        let status = b[1]
        motionActive = (status & 0x02) != 0
        motionEquipped = (status & 0x04) != 0
        magnetCount = u16(2)
        motionCount = u16(4)
        accelX = s16(6)
        accelY = s16(8)
        accelZ = s16(10)

        if b.count >= 14 {
            temperatureC = Double(s16(12)) / 10.0
        } else { temperatureC = nil }

        if b.count >= 16 {
            humidity = Double(u16(14)) / 10.0
        } else { humidity = nil }

        if b.count >= 18 {
            let batt = u16(16)
            if batt > 100 {
                batteryMilliVolts = batt
                batteryPercent = nil
            } else {
                batteryPercent = batt
                batteryMilliVolts = nil
            }
        } else {
            batteryMilliVolts = nil
            batteryPercent = nil
        }

        if b.count >= 24 {
            tagID = b[18..<24].map { String(format: "%02X", Int($0)) }.joined()
        } else {
            tagID = ""
        }
    }
}
