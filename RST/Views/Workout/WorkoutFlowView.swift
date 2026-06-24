import SwiftData
import SwiftUI

/// Drives a live workout session through the product flow. The weight itself
/// is set physically by placing the smart pin in the stack; in the app:
/// 1. scan machine → 2. read the stack (detects the pinned weight) → 3. lift,
/// then loops back for the next machine until the user finishes.
struct WorkoutFlowView: View {
    enum FlowStep {
        case machineScan
        case stackScan
        case lifting
        case betweenExercises
    }

    let template: WorkoutTemplate?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.catalogStore) private var catalogStore
    @Environment(\.locationService) private var locationService
    @Environment(\.pinDevice) private var pinDevice
    @AppStorage("gymProfileID") private var gymProfileID = "standard"
    @AppStorage("weightUnit") private var weightUnitRaw = WeightUnit.lb.rawValue

    @State private var workout: Workout?
    @State private var step: FlowStep = .machineScan
    @State private var machine: Machine?
    @State private var currentEntry: ExerciseEntry?
    @State private var plannedIndex = 0
    @State private var showEndConfirm = false

    private var unit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lb }
    private var catalog: EquipmentCatalog {
        catalogStore.catalog(id: template?.gymProfileID ?? gymProfileID)
    }
    private var plannedExercise: TemplateExercise? {
        guard let template else { return nil }
        let sorted = template.sortedExercises
        return plannedIndex < sorted.count ? sorted[plannedIndex] : nil
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("End") { showEndConfirm = true }
                            .foregroundStyle(Theme.warning)
                    }
                }
        }
        .preferredColorScheme(.dark)
        .fontDesign(.rounded)
        .interactiveDismissDisabled()
        .onAppear(perform: startWorkout)
        .confirmationDialog("End workout?", isPresented: $showEndConfirm, titleVisibility: .visible) {
            Button("Finish & Save") { finishWorkout(save: true) }
            Button("Discard Workout", role: .destructive) { finishWorkout(save: false) }
            Button("Keep Lifting", role: .cancel) {}
        }
    }

    private var title: String {
        switch step {
        case .machineScan: return "Scan Machine"
        case .stackScan: return "Read Stack"
        case .lifting: return machine?.name ?? "Lifting"
        case .betweenExercises: return template?.name ?? "Workout"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .machineScan:
            MachineScanView(planned: plannedExercise) { picked in
                machine = picked
                step = .stackScan
            }
        case .stackScan:
            if let machine {
                StackScanView(machine: machine,
                              plannedWeight: plannedExercise?.targetWeight,
                              unit: unit) { confirmed in
                    beginExercise(weight: confirmed)
                }
            }
        case .lifting:
            if let currentEntry, let machine {
                ActiveSetView(entry: currentEntry, machine: machine, planned: plannedExercise, unit: unit) {
                    step = .betweenExercises
                }
            }
        case .betweenExercises:
            betweenExercisesView
        }
    }

    private var betweenExercisesView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let workout {
                    HStack {
                        statBlock(value: "\(workout.exercises.count)", label: "Machines")
                        statBlock(value: "\(workout.totalSets)", label: "Sets")
                        statBlock(value: formatWeight(workout.totalVolume, unit: unit), label: "Volume")
                    }
                    .card()

                    if let template {
                        plannedProgress(template: template)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Logged so far")
                            .font(.headline)
                        ForEach(workout.sortedExercises) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.machineName).font(.subheadline.bold())
                                    Text("\(entry.sets.count) sets · \(entry.totalReps) reps")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(formatWeight(entry.weight, unit: unit))
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.accent)
                            }
                            .card()
                        }
                    }
                }

                Button {
                    nextExercise()
                } label: {
                    Label(plannedExercise == nil ? "Add Another Machine" : "Next: \(plannedExercise?.machineName ?? "")",
                          systemImage: "plus.circle.fill")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Finish Workout") {
                    finishWorkout(save: true)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding()
        }
        .background(Theme.background)
    }

    private func plannedProgress(template: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plan")
                .font(.headline)
            ForEach(Array(template.sortedExercises.enumerated()), id: \.element.persistentModelID) { index, exercise in
                HStack {
                    Image(systemName: index < plannedIndex ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(index < plannedIndex ? Theme.accent : .secondary)
                    Text(exercise.machineName)
                        .font(.subheadline)
                    Spacer()
                    Text("\(exercise.targetSets) × \(exercise.targetReps)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func statBlock(value: String, label: String) -> some View {
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

    // MARK: - Session lifecycle

    private func startWorkout() {
        guard workout == nil else { return }
        let newWorkout = Workout(gymProfileID: template?.gymProfileID ?? gymProfileID)
        modelContext.insert(newWorkout)
        workout = newWorkout
        locationService.requestLocation()
        applyLocation(to: newWorkout)
    }

    private func applyLocation(to workout: Workout) {
        if let location = locationService.current {
            workout.latitude = location.latitude
            workout.longitude = location.longitude
            workout.gymName = location.placeName ?? catalog.name
        } else {
            workout.gymName = catalog.name
        }
    }

    private func beginExercise(weight: Double) {
        guard let workout, let machine else { return }
        let entry = ExerciseEntry(machineID: machine.id, machineName: machine.name, weight: weight)
        workout.exercises.append(entry)
        currentEntry = entry
        step = .lifting
    }

    private func nextExercise() {
        if plannedExercise != nil {
            plannedIndex += 1
        }
        machine = nil
        currentEntry = nil
        step = .machineScan
    }

    private func finishWorkout(save: Bool) {
        pinDevice.disconnect()
        if let workout {
            // Refresh location in case it resolved while lifting.
            applyLocation(to: workout)
            if save && !workout.exercises.isEmpty {
                workout.endedAt = .now
            } else {
                modelContext.delete(workout)
            }
        }
        dismiss()
    }
}
