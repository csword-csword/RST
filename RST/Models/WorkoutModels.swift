import Foundation
import SwiftData

@Model
final class Workout {
    var startedAt: Date
    var endedAt: Date?
    var gymProfileID: String
    var gymName: String?
    var latitude: Double?
    var longitude: Double?
    @Relationship(deleteRule: .cascade, inverse: \ExerciseEntry.workout)
    var exercises: [ExerciseEntry] = []

    init(startedAt: Date = .now, gymProfileID: String = "standard") {
        self.startedAt = startedAt
        self.gymProfileID = gymProfileID
    }

    var duration: TimeInterval { (endedAt ?? .now).timeIntervalSince(startedAt) }
    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets.count } }
    var totalReps: Int { exercises.reduce(0) { $0 + $1.totalReps } }
    var totalVolume: Double { exercises.reduce(0) { $0 + $1.totalVolume } }
    var sortedExercises: [ExerciseEntry] { exercises.sorted { $0.startedAt < $1.startedAt } }
}

@Model
final class ExerciseEntry {
    var machineID: String
    var machineName: String
    var weight: Double
    var startedAt: Date
    var workout: Workout?
    @Relationship(deleteRule: .cascade, inverse: \SetRecord.exercise)
    var sets: [SetRecord] = []

    init(machineID: String, machineName: String, weight: Double, startedAt: Date = .now) {
        self.machineID = machineID
        self.machineName = machineName
        self.weight = weight
        self.startedAt = startedAt
    }

    var totalReps: Int { sets.reduce(0) { $0 + $1.reps } }
    var totalVolume: Double { sets.reduce(0) { $0 + Double($1.reps) * $1.weight } }
    var sortedSets: [SetRecord] { sets.sorted { $0.endedAt < $1.endedAt } }
}

@Model
final class SetRecord {
    var reps: Int
    var weight: Double
    var startedAt: Date
    var endedAt: Date
    var exercise: ExerciseEntry?

    init(reps: Int, weight: Double, startedAt: Date, endedAt: Date = .now) {
        self.reps = reps
        self.weight = weight
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

@Model
final class WorkoutTemplate {
    var name: String
    var gymProfileID: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.template)
    var exercises: [TemplateExercise] = []

    init(name: String, gymProfileID: String = "standard") {
        self.name = name
        self.gymProfileID = gymProfileID
        self.createdAt = .now
    }

    var sortedExercises: [TemplateExercise] { exercises.sorted { $0.order < $1.order } }
}

@Model
final class TemplateExercise {
    var machineID: String
    var machineName: String
    var targetSets: Int
    var targetReps: Int
    var targetWeight: Double
    var order: Int
    var template: WorkoutTemplate?

    init(machineID: String,
         machineName: String,
         targetSets: Int = 3,
         targetReps: Int = 10,
         targetWeight: Double = 50,
         order: Int) {
        self.machineID = machineID
        self.machineName = machineName
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.order = order
    }
}
