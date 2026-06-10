import Foundation

struct StackReading: Hashable {
    let weight: Double
    let confidence: Double
}

/// Abstraction over the camera-based weight-stack reader that infers the
/// loaded weight from the pin position. The smart pin's BLE beacon will
/// eventually confirm or override this reading.
protocol WeightStackReading: Sendable {
    func readStack(for machine: Machine, selectedWeight: Double?) async throws -> StackReading
}

struct MockWeightStackReader: WeightStackReading {
    var delay: Duration = .seconds(1.6)

    func readStack(for machine: Machine, selectedWeight: Double?) async throws -> StackReading {
        try await Task.sleep(for: delay)
        // Usually "reads" the weight the user intends to lift; occasionally
        // lands one pin position off so the mismatch UI is exercised.
        let target = machine.snappedWeight(selectedWeight ?? machine.stackMin)
        let offset = Double(Int.random(in: 0...4) == 0 ? Int.random(in: -1...1) : 0)
        let weight = machine.snappedWeight(target + offset * machine.increment)
        return StackReading(weight: weight, confidence: .random(in: 0.90...0.99))
    }
}
