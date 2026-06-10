import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("weightUnit") private var weightUnitRaw = WeightUnit.lb.rawValue
    @Query(filter: #Predicate<Workout> { $0.endedAt != nil },
           sort: \Workout.startedAt,
           order: .reverse)
    private var workouts: [Workout]

    private var unit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lb }

    var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty {
                    ContentUnavailableView(
                        "No workouts yet",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("Finish your first workout and it will show up here.")
                    )
                } else {
                    List {
                        ForEach(workouts) { workout in
                            NavigationLink(value: workout) {
                                WorkoutRow(workout: workout, unit: unit)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: Workout.self) { workout in
                WorkoutDetailView(workout: workout, unit: unit)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(workouts[index])
        }
    }
}

struct WorkoutDetailView: View {
    let workout: Workout
    let unit: WeightUnit

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                ForEach(workout.sortedExercises) { entry in
                    exerciseCard(entry)
                }
            }
            .padding()
        }
        .background(Theme.background)
        .navigationTitle(workout.startedAt.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label(workout.gymName ?? "Unknown location", systemImage: "mappin.and.ellipse")
                    .font(.headline)
                Text("\(workout.startedAt.formatted(date: .omitted, time: .shortened)) · \(formatDuration(workout.duration))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                stat(value: "\(workout.exercises.count)", label: "Machines")
                stat(value: "\(workout.totalSets)", label: "Sets")
                stat(value: "\(workout.totalReps)", label: "Reps")
                stat(value: formatWeight(workout.totalVolume, unit: unit), label: "Volume")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func exerciseCard(_ entry: ExerciseEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(entry.machineName)
                    .font(.headline)
                Spacer()
                Text(formatWeight(entry.weight, unit: unit))
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent)
            }
            ForEach(Array(entry.sortedSets.enumerated()), id: \.element.persistentModelID) { index, set in
                HStack {
                    Text("Set \(index + 1)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(set.reps) reps")
                        .font(.subheadline.bold())
                    Text("@ \(formatWeight(set.weight, unit: unit))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
