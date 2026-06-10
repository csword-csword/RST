import Foundation

/// A gym equipment catalog. The app ships a generic "standard" catalog plus
/// chain-specific catalogs (Planet Fitness, LA Fitness) that reflect the
/// machines those gyms actually carry.
struct EquipmentCatalog: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let machines: [Machine]
}

struct Machine: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let muscleGroups: [String]
    /// Weight-stack bounds and pin increment, in pounds.
    let stackMin: Double
    let stackMax: Double
    let increment: Double
}

extension Machine {
    /// Clamp a weight to the machine's stack range and round it to the
    /// nearest pin position.
    func snappedWeight(_ value: Double) -> Double {
        let clamped = min(max(value, stackMin), stackMax)
        let steps = ((clamped - stackMin) / increment).rounded()
        return stackMin + steps * increment
    }

    var weightOptions: [Double] {
        Array(stride(from: stackMin, through: stackMax, by: increment))
    }
}

extension Array where Element == Machine {
    var categories: [String] {
        var seen = Set<String>()
        return compactMap { seen.insert($0.category).inserted ? $0.category : nil }
    }
}
