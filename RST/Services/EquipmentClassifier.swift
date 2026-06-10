import Foundation

struct EquipmentDetection: Hashable {
    let machine: Machine
    let confidence: Double
}

enum EquipmentClassifierError: Error {
    case noCandidates
}

/// Abstraction over the on-device vision model that identifies what kind of
/// machine the camera is pointed at. Replace `MockEquipmentClassifier` with a
/// Core ML / Vision-backed implementation when the model is ready; candidates
/// are constrained to the active gym profile's catalog.
protocol EquipmentClassifying: Sendable {
    func classify(from candidates: [Machine]) async throws -> EquipmentDetection
}

struct MockEquipmentClassifier: EquipmentClassifying {
    var delay: Duration = .seconds(2)

    func classify(from candidates: [Machine]) async throws -> EquipmentDetection {
        try await Task.sleep(for: delay)
        guard let machine = candidates.randomElement() else {
            throw EquipmentClassifierError.noCandidates
        }
        return EquipmentDetection(machine: machine, confidence: .random(in: 0.86...0.99))
    }
}
