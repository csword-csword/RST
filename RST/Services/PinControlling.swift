import CoreBluetooth
import Foundation
import Observation

/// Connected-mode (GATT) control of the smart pin, used for one-off setup tasks
/// in Settings: first-time connection, changing the connection password, and
/// resetting the battery gauge after a battery swap.
///
/// This is separate from `PinDeviceService` (which only *scans* advertisements
/// to count reps). Those tasks require a authenticated connection.
@MainActor
protocol PinControlling: AnyObject, Observable {
    var state: PinControlState { get }
    var connectedInfo: PinDeviceInfo? { get }
    /// GATT table discovered on connect — useful for identifying the right
    /// characteristics while finalizing the MOKO command protocol.
    var discoveredCharacteristics: [String] { get }

    func connect(password: String) async throws
    func disconnect()
    func changePassword(current: String, new: String) async throws
    func resetBatteryGauge() async throws
}

enum PinControlState: Equatable {
    case idle
    case scanning
    case connecting
    case authenticating
    case connected
    case failed(String)
}

enum PinControlError: LocalizedError {
    case bluetoothUnavailable
    case deviceNotFound
    case connectionFailed
    case wrongPassword
    case timedOut
    case notConnected
    case writeFailed
    /// The MOKO connected-mode command protocol (characteristic UUIDs / opcodes)
    /// hasn't been supplied yet — see `MokoControlProtocol`.
    case protocolNotConfigured

    var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable: return "Bluetooth is off or unavailable."
        case .deviceNotFound: return "Couldn't find the pin. Make sure it's awake and nearby."
        case .connectionFailed: return "Failed to connect to the pin."
        case .wrongPassword: return "Incorrect password."
        case .timedOut: return "The pin didn't respond in time."
        case .notConnected: return "Connect to the pin first."
        case .writeFailed: return "The command couldn't be sent."
        case .protocolNotConfigured:
            return "The connected-mode command protocol isn't configured yet (see SENSOR_SETUP.md). Connection works, but password and battery commands need the MOKO command bytes."
        }
    }
}

/// Single source of truth for the MOKO connected-mode BLE protocol.
///
/// The advertisement layout (used for rep tracking) was fully documented in the
/// MK Sensor manual. The *connected* configuration protocol — the GATT service /
/// characteristic UUIDs and the command frames for authentication, changing the
/// password, and resetting the battery — is MOKO-proprietary and lives in the
/// "Data Format" spec / `MKBXPSeriesSlathf` SDK. Fill these in from that spec and
/// the connected operations light up; until then `isConfigured` is false and the
/// controller refuses to write (so it never sends incorrect bytes to a device).
enum MokoControlProtocol {
    static let defaultPassword = "Moko4321"

    // TODO: supply from the MOKO Data Format doc / SDK.
    static let configServiceUUID: CBUUID? = nil
    static let writeCharacteristicUUID: CBUUID? = nil
    static let notifyCharacteristicUUID: CBUUID? = nil

    static var isConfigured: Bool {
        configServiceUUID != nil && writeCharacteristicUUID != nil && notifyCharacteristicUUID != nil
    }

    /// Command frame to authenticate with the connection password.
    static func authCommand(password: String) -> Data? { nil }
    /// Command frame to set a new connection password.
    static func changePasswordCommand(new: String) -> Data? { nil }
    /// Command frame to reset the battery gauge to 100% after a battery swap.
    static func resetBatteryCommand() -> Data? { nil }
}

/// Simulated controller: drives the full Settings UX without hardware. Used in
/// the simulator and when "Use simulated pin" is enabled.
@Observable @MainActor
final class MockPinController: PinControlling {
    private(set) var state: PinControlState = .idle
    private(set) var connectedInfo: PinDeviceInfo?
    private(set) var discoveredCharacteristics: [String] = []

    // Default values initialize storage directly, which is allowed from a
    // nonisolated init (assignments in the init body would not be — the
    // @Observable macro makes property setters main-actor isolated).
    private var password: String = UserDefaults.standard.string(forKey: "mockPinPassword")
        ?? MokoControlProtocol.defaultPassword

    nonisolated init() {}

    func connect(password: String) async throws {
        state = .scanning
        try? await Task.sleep(for: .seconds(0.8))
        state = .connecting
        try? await Task.sleep(for: .seconds(0.7))
        state = .authenticating
        try? await Task.sleep(for: .seconds(0.6))
        guard password == self.password else {
            state = .failed("Incorrect password")
            throw PinControlError.wrongPassword
        }
        connectedInfo = PinDeviceInfo(name: "Simulated Pin",
                                      tagID: "000001",
                                      rssi: -42,
                                      batteryPercent: 64,
                                      batteryMilliVolts: nil)
        discoveredCharacteristics = ["EA01 (service data)", "FF01 (write)", "FF02 (notify)"]
        state = .connected
    }

    func disconnect() {
        state = .idle
        connectedInfo = nil
        discoveredCharacteristics = []
    }

    func changePassword(current: String, new: String) async throws {
        guard state == .connected else { throw PinControlError.notConnected }
        guard current == password else { throw PinControlError.wrongPassword }
        try? await Task.sleep(for: .seconds(0.6))
        password = new
        UserDefaults.standard.set(new, forKey: "mockPinPassword")
    }

    func resetBatteryGauge() async throws {
        guard state == .connected else { throw PinControlError.notConnected }
        try? await Task.sleep(for: .seconds(0.6))
        connectedInfo?.batteryPercent = 100
        connectedInfo?.batteryMilliVolts = nil
    }
}
