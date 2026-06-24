import Foundation

/// Matches text read off a machine's label/placard (via on-device OCR) against
/// the active gym's machine list. Pure and unit-tested; the Vision OCR that
/// produces the text lives in `LabelScannerView`.
enum EquipmentTextMatcher {
    /// Best machine for the recognized text, or nil if nothing clears `threshold`.
    static func bestMatch(in recognizedText: [String],
                          candidates: [Machine],
                          threshold: Double = 0.5) -> EquipmentDetection? {
        let haystack = normalize(recognizedText.joined(separator: " "))
        guard !haystack.isEmpty else { return nil }
        let haystackTokens = Set(haystack.split(separator: " ").map(String.init))

        var best: (machine: Machine, score: Double)?
        for machine in candidates {
            let s = score(machine: machine, haystack: haystack, haystackTokens: haystackTokens)
            if s > (best?.score ?? 0) { best = (machine, s) }
        }
        guard let best, best.score >= threshold else { return nil }
        let confidence = min(0.99, 0.6 + best.score * 0.39)
        return EquipmentDetection(machine: best.machine, confidence: confidence)
    }

    private static func score(machine: Machine, haystack: String, haystackTokens: Set<String>) -> Double {
        let name = normalize(machine.name)
        guard !name.isEmpty else { return 0 }
        // Whole machine name appears in the label → certain.
        if haystack.contains(name) { return 1.0 }

        // Otherwise score by the fraction of meaningful name words present,
        // weighted toward longer (more distinctive) words.
        let nameTokens = name.split(separator: " ").map(String.init).filter { $0.count >= 3 }
        guard !nameTokens.isEmpty else { return 0 }

        var matchedWeight = 0.0
        var totalWeight = 0.0
        for token in nameTokens {
            let weight = Double(token.count)
            totalWeight += weight
            if haystackTokens.contains(token) || haystack.contains(token) {
                matchedWeight += weight
            }
        }
        return totalWeight > 0 ? matchedWeight / totalWeight : 0
    }

    private static func normalize(_ string: String) -> String {
        string.uppercased()
            .replacingOccurrences(of: "[^A-Z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: " +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
