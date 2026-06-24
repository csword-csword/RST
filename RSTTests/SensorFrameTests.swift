import XCTest
@testable import RST

final class SensorFrameTests: XCTestCase {
    /// Builds a Sensor-info payload (the bytes iOS exposes after the 0xEA01
    /// UUID) using the worked example from the MOKO manual.
    private func sampleData() -> Data {
        var b: [UInt8] = []
        b.append(0x80)                  // frame type
        b.append(0x3C)                  // status: motion equipped, temp+humidity
        b.append(contentsOf: [0x00, 0x00])  // magnet cnt = 0
        b.append(contentsOf: [0x02, 0x00])  // motion cnt = 2
        b.append(contentsOf: [0x3A, 0x00])  // accel X = 58 mg
        b.append(contentsOf: [0x76, 0x00])  // accel Y = 118 mg
        b.append(contentsOf: [0xA7, 0x03])  // accel Z = 935 mg
        b.append(contentsOf: [0xC8, 0x00])  // temp = 200 -> 20.0 C
        b.append(contentsOf: [0x37, 0x01])  // humidity = 311 -> 31.1 %
        b.append(contentsOf: [0x64, 0x00])  // battery = 100 -> 100 %
        b.append(contentsOf: [0x00, 0x00, 0x01, 0x00, 0x00, 0x00]) // tag id
        return Data(b)
    }

    func testParsesManualExample() throws {
        let frame = try XCTUnwrap(PinSensorFrame(serviceData: sampleData()))
        XCTAssertEqual(frame.motionCount, 2)
        XCTAssertEqual(frame.accelX, 58)
        XCTAssertEqual(frame.accelY, 118)
        XCTAssertEqual(frame.accelZ, 935)
        XCTAssertTrue(frame.motionEquipped)
        XCTAssertFalse(frame.motionActive)
        XCTAssertEqual(frame.temperatureC ?? 0, 20.0, accuracy: 0.001)
        XCTAssertEqual(frame.humidity ?? 0, 31.1, accuracy: 0.001)
        XCTAssertEqual(frame.batteryPercent, 100)
        XCTAssertNil(frame.batteryMilliVolts)
        XCTAssertEqual(frame.tagID, "000001000000")
        XCTAssertEqual(frame.magnitudeG, 0.944, accuracy: 0.01)
    }

    func testSignedAcceleration() throws {
        var b = [UInt8](sampleData())
        b[6] = 0x88; b[7] = 0xFF  // X = 0xFF88 = -120 mg
        let frame = try XCTUnwrap(PinSensorFrame(serviceData: Data(b)))
        XCTAssertEqual(frame.accelX, -120)
    }

    func testBatteryVoltageWhenAbove100() throws {
        var b = [UInt8](sampleData())
        b[16] = 0xCC; b[17] = 0x0C  // 0x0CCC = 3276 mV
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
