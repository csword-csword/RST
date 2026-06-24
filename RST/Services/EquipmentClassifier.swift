import Foundation

struct EquipmentDetection: Hashable {
    let machine: Machine
    let confidence: Double
}

enum EquipmentClassifierError: Error {
    case noCandidates
}

/// Fallback classifier used on the simulator (no camera). The real recognition
/// path is on-device OCR of the machine's label — see `LabelScannerView` +
/// `EquipmentTextMatcher`. Candidates are constrained to the active gym catalog.
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
