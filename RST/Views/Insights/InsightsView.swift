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

    @State private var selectedMachineID: String?
    @State private var selectedStrengthDate: Date?
    @State private var selectedVolumeDate: Date?

    private var unit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lb }
    private var prs: [MachinePR] { WorkoutStats.personalRecords(from: workouts) }
    private var weekly: [WeekVolume] { WorkoutStats.weeklyVolume(from: workouts) }
    private var muscles: [MuscleVolume] {
        WorkoutStats.muscleVolume(from: workouts, catalog: catalogStore.catalog(id: gymProfileID))
    }
    private var strengthSeries: [StrengthPoint] {
        guard let id = selectedMachineID else { return [] }
        return WorkoutStats.oneRepMaxSeries(for: id, from: workouts)
    }
    private var selectedStrengthPoint: StrengthPoint? {
        guard let date = selectedStrengthDate else { return nil }
        return strengthSeries.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
    }
    private var selectedWeek: WeekVolume? {
        guard let date = selectedVolumeDate else { return nil }
        return weekly.min {
            abs($0.weekStart.timeIntervalSince(date)) < abs($1.weekStart.timeIntervalSince(date))
        }
    }

    var body: some View {
        Group {
            if workouts.isEmpty {
                ContentUnavailableView("No data yet", systemImage: "chart.bar",
                                       description: Text("Finish a few workouts to see records and trends."))
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        strengthCard
                        volumeCard
                        formCard
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
        .onAppear { if selectedMachineID == nil { selectedMachineID = prs.first?.machineID } }
    }

    // MARK: - Strength progression

    private var strengthCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Strength").font(.headline)
                Spacer()
                Picker("Machine", selection: $selectedMachineID) {
                    ForEach(prs) { pr in
                        Text(pr.machineName).tag(Optional(pr.machineID))
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.accent)
            }
            Text("Estimated 1-rep max over time")
                .font(.caption).foregroundStyle(.secondary)

            if strengthSeries.count >= 2 {
                Chart {
                    ForEach(strengthSeries) { point in
                        LineMark(x: .value("Date", point.date),
                                 y: .value("1RM", point.oneRepMax))
                            .foregroundStyle(Theme.accent)
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Date", point.date),
                                  y: .value("1RM", point.oneRepMax))
                            .foregroundStyle(Theme.accent)
                    }
                    if let sel = selectedStrengthPoint {
                        RuleMark(x: .value("Date", sel.date))
                            .foregroundStyle(.secondary.opacity(0.4))
                            .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .automatic)) {
                                valueBadge(formatWeight(sel.oneRepMax, unit: unit), sel.date)
                            }
                        PointMark(x: .value("Date", sel.date), y: .value("1RM", sel.oneRepMax))
                            .foregroundStyle(Theme.accent)
                            .symbolSize(180)
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXSelection(value: $selectedStrengthDate)
                .frame(height: 180)
            } else {
                Text("Log this machine in at least two workouts to see a trend.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: - Volume

    private var volumeCard: some View {
        let avg = weekly.isEmpty ? 0 : weekly.map(\.volume).reduce(0, +) / Double(weekly.count)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Weekly Volume").font(.headline)
            Chart {
                ForEach(weekly) { week in
                    BarMark(x: .value("Week", week.weekStart, unit: .weekOfYear),
                            y: .value("Volume", week.volume))
                        .foregroundStyle(selectedWeek == nil || selectedWeek?.id == week.id
                                         ? Theme.accent : Theme.accent.opacity(0.35))
                        .cornerRadius(4)
                }
                if avg > 0 {
                    RuleMark(y: .value("Average", avg))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("avg").font(.caption2).foregroundStyle(.secondary)
                        }
                }
                if let sel = selectedWeek {
                    RuleMark(x: .value("Week", sel.weekStart, unit: .weekOfYear))
                        .foregroundStyle(.clear)
                        .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .automatic)) {
                            valueBadge(formatWeight(sel.volume, unit: unit), sel.weekStart)
                        }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartXSelection(value: $selectedVolumeDate)
            .frame(height: 180)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func valueBadge(_ value: String, _ date: Date) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.caption.bold()).foregroundStyle(.primary)
            Text(date, format: .dateTime.month(.abbreviated).day())
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.accent.opacity(0.4), lineWidth: 1))
    }

    // MARK: - Tempo & form

    @ViewBuilder
    private var formCard: some View {
        if let form = WorkoutStats.formSummary(from: workouts) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Tempo & Form").font(.headline)

                HStack(spacing: 12) {
                    formStat(value: String(format: "%.1fs", form.avgCadence), label: "Avg rep")
                    formStat(value: String(format: "%.0fs", form.avgTimeUnderTension), label: "TUT / set")
                    if let fatigue = form.fatigueRatio {
                        formStat(value: String(format: "%.2f×", fatigue), label: "Fatigue")
                    }
                }

                HStack(spacing: 20) {
                    if let rc = form.repConsistency {
                        consistencyGauge(rc, label: "Reps")
                    }
                    if let cc = form.cadenceConsistency {
                        consistencyGauge(cc, label: "Tempo")
                    }
                    Spacer()
                }

                Text("Tempo is average rep time and within-set fatigue. Concentric/eccentric split needs the pin's high-rate connected stream.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    private func consistencyGauge(_ value: Double, label: String) -> some View {
        VStack(spacing: 4) {
            Gauge(value: value) {
                EmptyView()
            } currentValueLabel: {
                Text("\(Int(value * 100))")
                    .font(.caption.bold())
            }
            .gaugeStyle(.accessoryCircular)
            .tint(Theme.accent)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func formStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.bold()).foregroundStyle(Theme.accent)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.caption2).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Muscle balance

    @ViewBuilder
    private var muscleCard: some View {
        if !muscles.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Volume by Muscle Group").font(.headline)
                Chart(muscles) { muscle in
                    BarMark(x: .value("Volume", muscle.volume),
                            y: .value("Muscle", muscle.muscle))
                        .foregroundStyle(Theme.accentGradient)
                        .cornerRadius(4)
                }
                .frame(height: Double(muscles.count) * 28 + 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    // MARK: - Personal records

    private var prCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal Records").font(.headline)
            Chart(Array(prs.prefix(8))) { pr in
                BarMark(x: .value("1RM", pr.estimatedOneRepMax),
                        y: .value("Machine", pr.machineName))
                    .foregroundStyle(Theme.accent)
                    .cornerRadius(4)
                    .annotation(position: .trailing) {
                        Text(formatWeight(pr.estimatedOneRepMax, unit: unit))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
            }
            .chartXAxis(.hidden)
            .frame(height: Double(min(prs.count, 8)) * 30 + 10)

            Divider()

            ForEach(prs) { pr in
                HStack {
                    Text(pr.machineName).font(.subheadline.bold())
                    Spacer()
                    Text("\(formatWeight(pr.maxWeight, unit: unit)) · \(pr.maxReps) reps")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
