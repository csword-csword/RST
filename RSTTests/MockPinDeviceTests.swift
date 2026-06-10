import XCTest
@testable import RST

@MainActor
final class MockPinDeviceTests: XCTestCase {
    func testConnectTransitionsToConnected() async {
        let pin = MockPinDevice(connectDelay: 0.01)
        XCTAssertEqual(pin.connectionState, .disconnected)
        await pin.connect()
        XCTAssertEqual(pin.connectionState, .connected)
    }

    func testSetAccumulatesRepsThenRests() async throws {
        let pin = MockPinDevice(connectDelay: 0.01,
                                repInterval: 0.01...0.02,
                                repTarget: 5...5,
                                restDelay: 0.05)
        await pin.connect()
        pin.beginSet()
        XCTAssertEqual(pin.phase, .lifting)

        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(pin.repCount, 5)
        XCTAssertEqual(pin.phase, .resting, "set should auto-end after the rest delay")
    }

    func testEndSetStopsLifting() async {
        let pin = MockPinDevice(connectDelay: 0.01, repInterval: 10...11)
        await pin.connect()
        pin.beginSet()
        let reps = pin.endSet()
        XCTAssertEqual(reps, 0)
        XCTAssertEqual(pin.phase, .resting)
    }

    func testDisconnectResets() async {
        let pin = MockPinDevice(connectDelay: 0.01)
        await pin.connect()
        pin.beginSet()
        pin.disconnect()
        XCTAssertEqual(pin.connectionState, .disconnected)
        XCTAssertEqual(pin.phase, .idle)
        XCTAssertEqual(pin.repCount, 0)
    }
}
