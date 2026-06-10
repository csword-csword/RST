import Foundation

struct StackReading: Hashable {
    let weight: Double
    let confidence: Double
}

/// Abstraction over the camera-based weight-stack reader. The lifter sets the
/// weight physically by placing the smart pin in the stack; this service
/// infers the loaded weight from the pin's position. The pin's BLE beacon
/// will eventually confirm or override the camera reading.
protocol WeightStackReading: Sendable {
    /// `plannedWeight` is an optional hint from the workout plan; real
    /// implementations read the actual pin position regardless.
    func readStack(for machine: Machine, plannedWeight: Double?) async throws -> StackReading
}

struct MockWeightStackReader: WeightStackReading {
    var delay: Duration = .seconds(1.6)

    func readStack(for machine: Machine, plannedWeight: Double?) async throws -> StackReading {
        try await Task.sleep(for: delay)
        // Simulate where the lifter pinned the stack: usually the planned
        // weight when following a template (occasionally one position off,
        // to exercise the mismatch UI), otherwise a plausible mid-stack spot.
        let base: Double
        if let plannedWeight {
            let offset = Double(Int.random(in: 0...3) == 0 ? Int.random(in: -1...1) : 0)
            base = machine.snappedWeight(plannedWeight) + offset * machine.increment
        } else {
            let options = machine.weightOptions
            let midRange = options[(options.count / 4)...(options.count * 3 / 4)]
            base = midRange.randomElement() ?? machine.stackMin
        }
        return StackReading(weight: machine.snappedWeight(base), confidence: .random(in: 0.90...0.99))
    }
}
