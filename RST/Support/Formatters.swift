import Foundation

enum WeightUnit: String, CaseIterable, Identifiable {
    case lb
    case kg

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
}

/// All weights are stored in pounds; this converts for display only.
func formatWeight(_ pounds: Double, unit: WeightUnit) -> String {
    switch unit {
    case .lb:
        return "\(Int(pounds.rounded())) lb"
    case .kg:
        let kg = pounds * 0.45359237
        return String(format: "%.1f kg", kg)
    }
}

func formatDuration(_ interval: TimeInterval) -> String {
    let minutes = Int(interval) / 60
    if minutes < 60 { return "\(minutes) min" }
    return "\(minutes / 60) h \(minutes % 60) min"
}
