import SwiftData
import XCTest
@testable import RST

@MainActor
final class WorkoutStatsTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Workout.self, WorkoutTemplate.self, configurations: config)
        return ModelContext(container)
    }

    func testEstimatedOneRepMax() {
        XCTAssertEqual(WorkoutStats.estimatedOneRepMax(weight: 100, reps: 1), 100, accuracy: 0.001)
        XCTAssertEqual(WorkoutStats.estimatedOneRepMax(weight: 100, reps: 10),
                       100 * (1 + 10.0 / 30.0), accuracy: 0.001)
    }

    func testPersonalRecords() throws {
        let ctx = try makeContext()
        let workout = Workout()
        ctx.insert(workout)
        let exercise = ExerciseEntry(machineID: "lat-pulldown", machineName: "Lat Pulldown", weight: 100)
        workout.exercises.append(exercise)
        exercise.sets.append(SetRecord(reps: 10, weight: 100, startedAt: .now))
        exercise.sets.append(SetRecord(reps: 8, weight: 120, startedAt: .now))

        let prs = WorkoutStats.personalRecords(from: [workout])
        XCTAssertEqual(prs.count, 1)
        let pr = try XCTUnwrap(prs.first)
        XCTAssertEqual(pr.maxWeight, 120)
        XCTAssertEqual(pr.maxReps, 10)
        XCTAssertEqual(pr.bestSetVolume, 1000)  // 10×100 beats 8×120=960
        XCTAssertEqual(pr.estimatedOneRepMax, 120 * (1 + 8.0 / 30.0), accuracy: 0.01)
    }

    func testWeeklyVolumeBucketsCurrentWeek() throws {
        let ctx = try makeContext()
        let cal = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let workout = Workout(startedAt: now)
        workout.endedAt = now
        ctx.insert(workout)
        let exercise = ExerciseEntry(machineID: "m", machineName: "M", weight: 50, startedAt: now)
        workout.exercises.append(exercise)
        exercise.sets.append(SetRecord(reps: 10, weight: 50, startedAt: now, endedAt: now))

        let series = WorkoutStats.weeklyVolume(from: [workout], weeks: 4, calendar: cal, now: now)
        XCTAssertEqual(series.count, 4)
        XCTAssertEqual(series.last?.volume, 500)          // current week holds the workout
        XCTAssertEqual(series.dropLast().reduce(0) { $0 + $1.volume }, 0)
    }
}
