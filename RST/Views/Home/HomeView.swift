import SwiftData
import SwiftUI

struct WorkoutLaunch: Identifiable {
    let id = UUID()
    let template: WorkoutTemplate?
}

struct HomeView: View {
    @Environment(\.catalogStore) private var catalogStore
    @Environment(\.locationService) private var locationService
    @AppStorage("gymProfileID") private var gymProfileID = "standard"
    @AppStorage("weightUnit") private var weightUnitRaw = WeightUnit.lb.rawValue
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse) private var templates: [WorkoutTemplate]
    @State private var launch: WorkoutLaunch?

    private var unit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lb }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    gymCard
                    startCard
                    if !templates.isEmpty {
                        templateRow
                    }
                    weekCard
                    if !workouts.isEmpty {
                        recentSection
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle("Pinpoint")
        }
        .onAppear { locationService.requestLocation() }
        .fullScreenCover(item: $launch) { launch in
            WorkoutFlowView(template: launch.template)
        }
    }

    private var gymCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.title3)
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(catalogStore.catalog(id: gymProfileID).name)
                    .font(.headline)
                Text(locationService.current?.placeName ?? "Locating…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .card()
    }

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Date.now, format: .dateTime.weekday(.wide).month().day())
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Ready to lift?")
                .font(.largeTitle.bold())
            Button {
                launch = WorkoutLaunch(template: nil)
            } label: {
                Label("Start Workout", systemImage: "bolt.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var templateRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Workouts")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(templates) { template in
                        Button {
                            launch = WorkoutLaunch(template: template)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(template.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text("\(template.exercises.count) exercises")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Label("Start", systemImage: "play.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(Theme.accent)
                            }
                            .frame(width: 150, alignment: .leading)
                            .card()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var thisWeek: [Workout] {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return workouts.filter { $0.startedAt >= start }
    }

    private var weekCard: some View {
        HStack {
            stat(value: "\(thisWeek.count)", label: "Workouts")
            Divider().frame(height: 36)
            stat(value: "\(thisWeek.reduce(0) { $0 + $1.totalSets })", label: "Sets")
            Divider().frame(height: 36)
            stat(value: formatWeight(thisWeek.reduce(0) { $0 + $1.totalVolume }, unit: unit), label: "Volume")
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent")
                .font(.headline)
            ForEach(workouts.prefix(3)) { workout in
                WorkoutRow(workout: workout, unit: unit)
                    .card()
            }
        }
    }
}

struct WorkoutRow: View {
    let workout: Workout
    let unit: WeightUnit

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.startedAt, format: .dateTime.weekday(.abbreviated).month().day().hour().minute())
                    .font(.subheadline.bold())
                Text(workout.gymName ?? "Unknown location")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(workout.totalSets) sets")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.accent)
                Text(formatDuration(workout.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
