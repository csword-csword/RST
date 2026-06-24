import Charts
import SwiftData
import SwiftUI

/// Pro feature: personal records and training analytics over all history.
struct InsightsView: View {
    @Environment(\.catalogStore) private var catalogStore
    @AppStorage("gymProfileID") private var gymProfileID = "standard"
    @AppStorage("weightUnit") private var weightUnitRaw = WeightUnit.lb.rawValue
    @Query(filter: #Predicate<Workout> { $0.endedAt != nil },
           sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]

    private var unit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lb }
    private var prs: [MachinePR] { WorkoutStats.personalRecords(from: workouts) }
    private var weekly: [WeekVolume] { WorkoutStats.weeklyVolume(from: workouts) }
    private var muscles: [MuscleVolume] {
        WorkoutStats.muscleVolume(from: workouts, catalog: catalogStore.catalog(id: gymProfileID))
    }

    var body: some View {
        Group {
            if workouts.isEmpty {
                ContentUnavailableView("No data yet", systemImage: "chart.bar",
                                       description: Text("Finish a few workouts to see records and trends."))
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        volumeCard
                        muscleCard
                        prCard
                    }
                    .padding()
                }
            }
        }
        .background(Theme.background)
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var volumeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weekly Volume").font(.headline)
            Chart(weekly) { week in
                BarMark(
                    x: .value("Week", week.weekStart, unit: .weekOfYear),
                    y: .value("Volume", week.volume)
                )
                .foregroundStyle(Theme.accent)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .frame(height: 180)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    @ViewBuilder
    private var muscleCard: some View {
        if !muscles.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Volume by Muscle Group").font(.headline)
                Chart(muscles) { muscle in
                    BarMark(
                        x: .value("Volume", muscle.volume),
                        y: .value("Muscle", muscle.muscle)
                    )
                    .foregroundStyle(Theme.accentGradient)
                    .cornerRadius(4)
                }
                .frame(height: Double(muscles.count) * 28 + 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    private var prCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Personal Records").font(.headline)
            ForEach(prs) { pr in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(pr.machineName).font(.subheadline.bold())
                        Spacer()
                        Text("est. 1RM \(formatWeight(pr.estimatedOneRepMax, unit: unit))")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.accent)
                    }
                    Text("Best: \(formatWeight(pr.maxWeight, unit: unit)) · \(pr.maxReps) reps · \(formatWeight(pr.bestSetVolume, unit: unit)) top set")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                if pr.id != prs.last?.id { Divider() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
