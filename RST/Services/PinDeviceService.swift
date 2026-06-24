import Foundation
import Observation

enum PinConnectionState: Equatable {
    case disconnected
    case scanning
    case connected
}

enum SetPhase: Equatable {
    case idle
    case lifting
    case resting
}

/// Live info about the connected pin, surfaced in Settings and during a set.
struct PinDeviceInfo: Equatable {
    var name: String
    var tagID: String
    var rssi: Int?
    var batteryPercent: Int?
    var batteryMilliVolts: Int?

    var batteryDescription: String? {
        if let pct = batteryPercent { return "\(pct)%" }
        if let mv = batteryMilliVolts { return String(format: "%.2f V", Double(mv) / 1000.0) }
        return nil
    }
}

/// Abstraction over the smart-pin hardware: the MOKO M1Pro sensor (Bluetooth
/// beacon + 3-axis accelerometer) that replaces the standard weight-stack pin.
///
/// Two implementations satisfy this protocol:
/// - `MokoPinDevice` — real CoreBluetooth, parses the sensor's advertisement
///   and counts reps from the broadcast acceleration. Used on device.
/// - `MockPinDevice` — simulates a realistic session. Used in the simulator and
///   for demos.
@MainActor
protocol PinDeviceService: AnyObject, Observable {
    var connectionState: PinConnectionState { get }
    var phase: SetPhase { get }
    var repCount: Int { get }
    /// Latest connected pin's info, or nil when none is locked on.
    var deviceInfo: PinDeviceInfo? { get }
    /// Current dynamic-acceleration magnitude (g), for live UI feedback.
    var liveAcceleration: Double { get }

    func connect() async
    func disconnect()
    func beginSet()
    @discardableResult func endSet() -> Int
}

@Observable @MainActor
final class MockPinDevice: PinDeviceService {
    private(set) var connectionState: PinConnectionState = .disconnected
    private(set) var phase: SetPhase = .idle
    private(set) var repCount: Int = 0
    private(set) var deviceInfo: PinDeviceInfo?
    private(set) var liveAcceleration: Double = 0

    private let connectDelay: Double
    private let repInterval: ClosedRange<Double>
    private let repTarget: ClosedRange<Int>
    private let restDelay: Double
    private var repTask: Task<Void, Never>?

    nonisolated init(connectDelay: Double = 1.5,
                     repInterval: ClosedRange<Double> = 2.0...3.5,
                     repTarget: ClosedRange<Int> = 6...12,
                     restDelay: Double = 4.0) {
        self.connectDelay = connectDelay
        self.repInterval = repInterval
        self.repTarget = repTarget
        self.restDelay = restDelay
    }

    func connect() async {
        guard connectionState == .disconnected else { return }
        connectionState = .scanning
        try? await Task.sleep(for: .seconds(connectDelay))
        connectionState = .connected
        deviceInfo = PinDeviceInfo(name: "Simulated Pin",
                                   tagID: "000001",
                                   rssi: -45,
                                   batteryPercent: 87,
                                   batteryMilliVolts: nil)
    }

    func disconnect() {
        repTask?.cancel()
        repTask = nil
        connectionState = .disconnected
        phase = .idle
        repCount = 0
        liveAcceleration = 0
        deviceInfo = nil
    }

    /// Starts streaming simulated accelerometer rep events: a rep every few
    /// seconds, then a pause that the device interprets as the end of a set.
    func beginSet() {
        repTask?.cancel()
        repCount = 0
        phase = .lifting
        let target = Int.random(in: repTarget)
        repTask = Task { [weak self] in
            guard let self else { return }
            for _ in 0..<target {
                try? await Task.sleep(for: .seconds(.random(in: self.repInterval)))
                guard !Task.isCancelled, self.phase == .lifting else { return }
                self.repCount += 1
                self.liveAcceleration = .random(in: 0.4...0.8)
                Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(350))
                    self?.liveAcceleration = 0
                }
            }
            try? await Task.sleep(for: .seconds(self.restDelay))
            guard !Task.isCancelled, self.phase == .lifting else { return }
            self.phase = .resting
        }
    }

    @discardableResult
    func endSet() -> Int {
        repTask?.cancel()
        repTask = nil
        if phase == .lifting {
            phase = .resting
        }
        liveAcceleration = 0
        return repCount
    }
}
