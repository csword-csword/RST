import XCTest
@testable import RST

final class SensorFrameTests: XCTestCase {
    /// Builds a Sensor-info payload (the bytes iOS exposes after the 0xEA01
    /// UUID) using the worked example from the MOKO data-format spec, which is
    /// big-endian (MSB first).
    private func sampleData() -> Data {
        var b: [UInt8] = []
        b.append(0x80)                  // frame type
        b.append(0x0C)                  // status: accel equipped (bit2) + temp (bit3)
        b.append(contentsOf: [0x00, 0x00])  // hall cnt = 0
        b.append(contentsOf: [0x00, 0x00])  // motion cnt = 0
        b.append(contentsOf: [0x00, 0x28])  // accel X = 0x0028 = 40 mg
        b.append(contentsOf: [0xFF, 0x84])  // accel Y = 0xFF84 = -124 mg
        b.append(contentsOf: [0x03, 0xD8])  // accel Z = 0x03D8 = 984 mg
        b.append(contentsOf: [0x00, 0xC8])  // temp = 0x00C8 = 200 -> 20.0 C
        b.append(contentsOf: [0x01, 0x37])  // humidity = 0x0137 = 311 -> 31.1 %
        b.append(contentsOf: [0x00, 0x64])  // battery = 0x0064 = 100 -> 100 %
        b.append(contentsOf: [0x00, 0x00, 0x01, 0x00, 0x00, 0x00]) // tag id
        return Data(b)
    }

    func testParsesSpecExample() throws {
        let frame = try XCTUnwrap(PinSensorFrame(serviceData: sampleData()))
        XCTAssertEqual(frame.motionCount, 0)
        XCTAssertEqual(frame.accelX, 40)
        XCTAssertEqual(frame.accelY, -124)
        XCTAssertEqual(frame.accelZ, 984)
        XCTAssertTrue(frame.motionEquipped)
        XCTAssertFalse(frame.motionActive)
        XCTAssertEqual(frame.temperatureC ?? 0, 20.0, accuracy: 0.001)
        XCTAssertEqual(frame.humidity ?? 0, 31.1, accuracy: 0.001)
        XCTAssertEqual(frame.batteryPercent, 100)
        XCTAssertNil(frame.batteryMilliVolts)
        XCTAssertEqual(frame.magnitudeG, 0.993, accuracy: 0.01)
    }

    func testSignedAcceleration() throws {
        var b = [UInt8](sampleData())
        b[6] = 0xFF; b[7] = 0x88  // X = 0xFF88 = -120 mg (big-endian)
        let frame = try XCTUnwrap(PinSensorFrame(serviceData: Data(b)))
        XCTAssertEqual(frame.accelX, -120)
    }

    func testBatteryVoltageWhenAbove100() throws {
        var b = [UInt8](sampleData())
        b[16] = 0x0C; b[17] = 0xCC  // 0x0CCC = 3276 mV (big-endian)
        let frame = try XCTUnwrap(PinSensorFrame(serviceData: Data(b)))
        XCTAssertEqual(frame.batteryMilliVolts, 3276)
        XCTAssertNil(frame.batteryPercent)
    }

    func testRejectsWrongFrameType() {
        var b = [UInt8](sampleData())
        b[0] = 0x70  // not Sensor info
        XCTAssertNil(PinSensorFrame(serviceData: Data(b)))
    }

    func testRejectsTooShort() {
        XCTAssertNil(PinSensorFrame(serviceData: Data([0x80, 0x3C, 0x00])))
    }
}
