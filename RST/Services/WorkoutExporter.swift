import Foundation

/// Builds a CSV export of workout history — the first Pinpoint Pro feature.
/// One row per set, so the file drops straight into a spreadsheet.
enum WorkoutExporter {
    static func csv(from workouts: [Workout], unit: WeightUnit) -> String {
        let dateFmt = DateFormatter(); dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter(); timeFmt.dateFormat = "HH:mm"

        var rows = ["Date,Time,Gym,Machine,Set,Reps,Weight (\(unit.label))"]
        for workout in workouts.sorted(by: { $0.startedAt > $1.startedAt }) {
            let date = dateFmt.string(from: workout.startedAt)
            let time = timeFmt.string(from: workout.startedAt)
            let gym = field(workout.gymName ?? "")
            for exercise in workout.sortedExercises {
                let machine = field(exercise.machineName)
                for (index, set) in exercise.sortedSets.enumerated() {
                    rows.append("\(date),\(time),\(gym),\(machine),\(index + 1),\(set.reps),\(weight(set.weight, unit))")
                }
            }
        }
        return rows.joined(separator: "\n")
    }

    /// Writes the CSV to a temp file and returns its URL (for the share sheet).
    static func writeTempFile(from workouts: [Workout], unit: WeightUnit) -> URL? {
        let csv = csv(from: workouts, unit: unit)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pinpoint-workouts.csv")
        do {
            try csv.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func weight(_ pounds: Double, _ unit: WeightUnit) -> String {
        switch unit {
        case .lb: return String(Int(pounds.rounded()))
        case .kg: return String(format: "%.1f", pounds * 0.45359237)
        }
    }

    /// Quote a text field and escape embedded quotes for CSV safety.
    private static func field(_ text: String) -> String {
        guard text.contains(",") || text.contains("\"") || text.contains("\n") else { return text }
        return "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
