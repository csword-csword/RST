import Foundation

/// One line of text read off a machine label, with its relative font size
/// (Vision bounding-box height, 0–1). The machine name is usually the largest
/// text, so prominence helps it outrank fine-print instructions.
struct RecognizedLine {
    let text: String
    let prominence: Double
}

/// Matches text read off a machine's label against the **universal** machine
/// taxonomy (`EquipmentCatalogStore.master`), using every recognized line plus
/// aliases — so it works at any gym, and a multi-line label (name + usage
/// description + muscles) resolves to the name rather than the description.
///
/// Pure and unit-tested; the Vision OCR that produces the lines lives in
/// `LabelScannerView`.
enum EquipmentTextMatcher {
    static func bestMatch(in lines: [RecognizedLine],
                          candidates: [Machine],
                          threshold: Double = 0.5) -> EquipmentDetection? {
        let fullText = normalize(lines.map(\.text).joined(separator: " "))
        guard !fullText.isEmpty else { return nil }

        var best: (machine: Machine, score: Double)?
        for machine in candidates {
            let s = score(machine: machine, lines: lines, fullText: fullText)
            if s > (best?.score ?? 0) { best = (machine, s) }
        }
        guard let best, best.score >= threshold else { return nil }
        let confidence = min(0.99, 0.55 + best.score * 0.44)
        return EquipmentDetection(machine: best.machine, confidence: confidence)
    }

    /// Convenience for plain strings (no prominence) — used by tests.
    static func bestMatch(strings texts: [String],
                          candidates: [Machine],
                          threshold: Double = 0.5) -> EquipmentDetection? {
        bestMatch(in: texts.map { RecognizedLine(text: $0, prominence: 0.5) },
                  candidates: candidates, threshold: threshold)
    }

    private static func score(machine: Machine, lines: [RecognizedLine], fullText: String) -> Double {
        var best = 0.0
        for name in machine.allNames {
            let target = normalize(name)
            guard !target.isEmpty else { continue }
            for line in lines {
                let base = nameScore(target, in: normalize(line.text))
                if base > 0 {
                    // A strong match on a large (prominent) line scores highest.
                    best = max(best, base * (0.75 + 0.25 * line.prominence))
                }
            }
            // Whole-label substring catches names split across wrapped lines.
            if fullText.contains(target) { best = max(best, 0.85) }
        }
        // Small corroboration if the label also lists this machine's muscles.
        let muscleHit = machine.muscleGroups.contains { fullText.contains(normalize($0)) }
        return min(1.0, best + (muscleHit ? 0.05 : 0))
    }

    /// 1.0 for a full substring match, otherwise the weighted fraction of the
    /// name's distinctive words present in the line.
    private static func nameScore(_ name: String, in line: String) -> Double {
        guard !line.isEmpty else { return 0 }
        if line.contains(name) { return 1.0 }
        let tokens = name.split(separator: " ").map(String.init).filter { $0.count >= 3 }
        guard !tokens.isEmpty else { return 0 }
        let lineTokens = Set(line.split(separator: " ").map(String.init))
        var matched = 0.0, total = 0.0
        for token in tokens {
            let weight = Double(token.count)
            total += weight
            if lineTokens.contains(token) || line.contains(token) { matched += weight }
        }
        return total > 0 ? matched / total : 0
    }

    private static func normalize(_ string: String) -> String {
        string.uppercased()
            .replacingOccurrences(of: "[^A-Z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: " +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
