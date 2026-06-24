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

struct StrengthPoint: Identifiable {
    let date: Date
    let oneRepMax: Double
    var id: Date { date }
}

struct MuscleVolume: Identifiable {
    let muscle: String
    let volume: Double
    var id: String { muscle }
}

/// Rep-quality summary across history. Tempo here is *average rep time* and a
/// fatigue trend (reps slowing within a set) — the concentric/eccentric split
/// needs the pin's high-rate connected accelerometer stream (not yet available).
struct FormSummary {
    let avgCadence: Double          // seconds per rep
    let avgTimeUnderTension: Double // seconds of work per set
    let fatigueRatio: Double?       // last-rep time ÷ first-rep time within sets (>1 = slowing)
    let repConsistency: Double?     // 0–1 (higher = steadier reps-per-set)
    let cadenceConsistency: Double? // 0–1 (higher = steadier rep timing)
    let scoredSets: Int
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

    /// Best estimated 1RM for one machine per workout, oldest → newest — the
    /// strength-progression line.
    static func oneRepMaxSeries(for machineID: String, from workouts: [Workout]) -> [StrengthPoint] {
        var points: [StrengthPoint] = []
        for workout in workouts {
            let best = workout.exercises
                .filter { $0.machineID == machineID }
                .flatMap { $0.sets }
                .map { estimatedOneRepMax(weight: $0.weight, reps: $0.reps) }
                .max()
            if let best { points.append(StrengthPoint(date: workout.startedAt, oneRepMax: best)) }
        }
        return points.sorted { $0.date < $1.date }
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

    // MARK: - Rep quality (tempo / TUT / cadence / consistency)

    /// Per-rep intervals (seconds) from the captured timestamps.
    static func repIntervals(_ set: SetRecord) -> [Double] {
        guard set.repOffsets.count >= 2 else { return [] }
        return zip(set.repOffsets.dropFirst(), set.repOffsets).map { $0 - $1 }
    }

    /// Time under tension for a set: span from first to last rep when we have
    /// per-rep timestamps, otherwise the recorded set duration.
    static func timeUnderTension(_ set: SetRecord) -> Double? {
        if let first = set.repOffsets.first, let last = set.repOffsets.last, last > first {
            return last - first
        }
        let duration = set.endedAt.timeIntervalSince(set.startedAt)
        return duration > 0 ? duration : nil
    }

    /// Average seconds per rep (cadence) for a set.
    static func cadence(_ set: SetRecord) -> Double? {
        let intervals = repIntervals(set)
        if !intervals.isEmpty { return mean(intervals) }
        let duration = set.endedAt.timeIntervalSince(set.startedAt)
        return (set.reps > 0 && duration > 0) ? duration / Double(set.reps) : nil
    }

    static func formSummary(from workouts: [Workout]) -> FormSummary? {
        var cadences: [Double] = []
        var tuts: [Double] = []
        var fatigue: [Double] = []
        var repCVs: [Double] = []
        var cadenceCVs: [Double] = []

        for workout in workouts {
            for exercise in workout.exercises {
                let sets = exercise.sets
                guard !sets.isEmpty else { continue }

                var setCadences: [Double] = []
                for set in sets {
                    if let cad = cadence(set) { cadences.append(cad); setCadences.append(cad) }
                    if let tut = timeUnderTension(set) { tuts.append(tut) }
                    let intervals = repIntervals(set)
                    if let first = intervals.first, let last = intervals.last, first > 0 {
                        fatigue.append(last / first)
                    }
                }
                if sets.count >= 2 {
                    if let cv = coefficientOfVariation(sets.map { Double($0.reps) }) { repCVs.append(cv) }
                    if setCadences.count >= 2, let cv = coefficientOfVariation(setCadences) { cadenceCVs.append(cv) }
                }
            }
        }

        guard !cadences.isEmpty else { return nil }
        return FormSummary(
            avgCadence: mean(cadences),
            avgTimeUnderTension: tuts.isEmpty ? 0 : mean(tuts),
            fatigueRatio: fatigue.isEmpty ? nil : mean(fatigue),
            repConsistency: repCVs.isEmpty ? nil : max(0, 1 - mean(repCVs)),
            cadenceConsistency: cadenceCVs.isEmpty ? nil : max(0, 1 - mean(cadenceCVs)),
            scoredSets: tuts.count
        )
    }

    // MARK: - Helpers

    private static func mean(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    private static func coefficientOfVariation(_ values: [Double]) -> Double? {
        guard values.count >= 2 else { return nil }
        let m = mean(values)
        guard m > 0 else { return nil }
        let variance = values.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(values.count)
        return variance.squareRoot() / m
    }
}
