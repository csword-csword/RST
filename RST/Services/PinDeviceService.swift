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

/// Abstraction over the smart-pin hardware: a Bluetooth beacon plus
/// accelerometer that replaces the standard weight-stack pin. The real
/// implementation will use CoreBluetooth and the device SDK; `MockPinDevice`
/// simulates a realistic session so the live-workout UI is fully demoable.
@MainActor
protocol PinDeviceService: AnyObject, Observable {
    var connectionState: PinConnectionState { get }
    var phase: SetPhase { get }
    var repCount: Int { get }
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
    }

    func disconnect() {
        repTask?.cancel()
        repTask = nil
        connectionState = .disconnected
        phase = .idle
        repCount = 0
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
        return repCount
    }
}
