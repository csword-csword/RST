import Foundation

struct MachinePR: Identifiable {
    let machineID: String
    let machineName: String
    let maxWeight: Double
    let maxReps: Int
    let bestSetVolume: Double      // best single set: reps × weight
    let estimatedOneRepMax: Double
    var id: String { machineID }
}

struct WeekVolume: Identifiable {
    let weekStart: Date
    let volume: Double
    var id: Date { weekStart }
}

struct MuscleVolume: Identifiable {
    let muscle: String
    let volume: Double
    var id: String { muscle }
}

/// Pure analytics over workout history — the basis for the Pro Insights screen.
enum WorkoutStats {
    /// Epley estimate; equals the lifted weight for a true 1-rep set.
    static func estimatedOneRepMax(weight: Double, reps: Int) -> Double {
        reps <= 1 ? weight : weight * (1.0 + Double(reps) / 30.0)
    }

    /// Best-ever records per machine, sorted by estimated 1RM.
    static func personalRecords(from workouts: [Workout]) -> [MachinePR] {
        struct Acc {
            var name: String
            var maxWeight = 0.0
            var maxReps = 0
            var bestSetVolume = 0.0
            var best1RM = 0.0
        }
        var byMachine: [String: Acc] = [:]
        for workout in workouts {
            for exercise in workout.exercises {
                var acc = byMachine[exercise.machineID] ?? Acc(name: exercise.machineName)
                acc.name = exercise.machineName
                for set in exercise.sets {
                    acc.maxWeight = max(acc.maxWeight, set.weight)
                    acc.maxReps = max(acc.maxReps, set.reps)
                    acc.bestSetVolume = max(acc.bestSetVolume, Double(set.reps) * set.weight)
                    acc.best1RM = max(acc.best1RM, estimatedOneRepMax(weight: set.weight, reps: set.reps))
                }
                byMachine[exercise.machineID] = acc
            }
        }
        return byMachine.map { id, acc in
            MachinePR(machineID: id, machineName: acc.name, maxWeight: acc.maxWeight,
                      maxReps: acc.maxReps, bestSetVolume: acc.bestSetVolume,
                      estimatedOneRepMax: acc.best1RM)
        }
        .sorted { $0.estimatedOneRepMax > $1.estimatedOneRepMax }
    }

    /// Total volume per week for the last `weeks` weeks (oldest → newest).
    static func weeklyVolume(from workouts: [Workout],
                             weeks: Int = 8,
                             calendar: Calendar = .current,
                             now: Date = Date()) -> [WeekVolume] {
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        var buckets: [Date: Double] = [:]
        var starts: [Date] = []
        for offset in stride(from: weeks - 1, through: 0, by: -1) {
            guard let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: thisWeekStart) else { continue }
            starts.append(start)
            buckets[start] = 0
        }
        for workout in workouts {
            guard let start = calendar.dateInterval(of: .weekOfYear, for: workout.startedAt)?.start,
                  buckets[start] != nil else { continue }
            buckets[start, default: 0] += workout.totalVolume
        }
        return starts.map { WeekVolume(weekStart: $0, volume: buckets[$0] ?? 0) }
    }

    /// Volume attributed to each muscle group (split evenly across an exercise's
    /// muscles), sorted high → low. Needs the catalog for machine → muscles.
    static func muscleVolume(from workouts: [Workout], catalog: EquipmentCatalog) -> [MuscleVolume] {
        let muscles = Dictionary(uniqueKeysWithValues: catalog.machines.map { ($0.id, $0.muscleGroups) })
        var totals: [String: Double] = [:]
        for workout in workouts {
            for exercise in workout.exercises {
                let groups = muscles[exercise.machineID] ?? []
                guard !groups.isEmpty else { continue }
                let share = exercise.totalVolume / Double(groups.count)
                for group in groups { totals[group, default: 0] += share }
            }
        }
        return totals.map { MuscleVolume(muscle: $0.key, volume: $0.value) }
            .sorted { $0.volume > $1.volume }
    }
}
