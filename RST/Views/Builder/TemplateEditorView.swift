import SwiftData
import SwiftUI

struct TemplateEditorView: View {
    @Bindable var template: WorkoutTemplate
    @Environment(\.catalogStore) private var catalogStore
    @Environment(\.modelContext) private var modelContext
    @AppStorage("weightUnit") private var weightUnitRaw = WeightUnit.lb.rawValue
    @State private var showMachinePicker = false

    private var unit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lb }
    private var catalog: EquipmentCatalog { catalogStore.catalog(id: template.gymProfileID) }

    var body: some View {
        Form {
            Section("Workout") {
                TextField("Name", text: $template.name)
                Picker("Gym profile", selection: $template.gymProfileID) {
                    ForEach(catalogStore.catalogs) { catalog in
                        Text(catalog.name).tag(catalog.id)
                    }
                }
            }

            Section {
                ForEach(template.sortedExercises) { exercise in
                    TemplateExerciseRow(exercise: exercise, catalog: catalog, unit: unit)
                }
                .onDelete(perform: deleteExercises)
                .onMove(perform: moveExercises)

                Button {
                    showMachinePicker = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                        .foregroundStyle(Theme.accent)
                }
            } header: {
                Text("Exercises")
            } footer: {
                Text("Exercises come from the \(catalog.name) equipment list.")
            }
        }
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .sheet(isPresented: $showMachinePicker) {
            MachinePickerView(machines: catalog.machines) { machine in
                addExercise(machine: machine)
            }
        }
    }

    private func addExercise(machine: Machine) {
        let exercise = TemplateExercise(machineID: machine.id,
                                        machineName: machine.name,
                                        targetWeight: machine.snappedWeight(machine.stackMin + (machine.stackMax - machine.stackMin) / 4),
                                        order: template.exercises.count)
        template.exercises.append(exercise)
    }

    private func deleteExercises(at offsets: IndexSet) {
        let sorted = template.sortedExercises
        for index in offsets {
            modelContext.delete(sorted[index])
        }
        for (newOrder, exercise) in template.sortedExercises.enumerated() {
            exercise.order = newOrder
        }
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        var sorted = template.sortedExercises
        sorted.move(fromOffsets: source, toOffset: destination)
        for (newOrder, exercise) in sorted.enumerated() {
            exercise.order = newOrder
        }
    }
}

struct TemplateExerciseRow: View {
    @Bindable var exercise: TemplateExercise
    let catalog: EquipmentCatalog
    let unit: WeightUnit

    private var machine: Machine? {
        catalog.machines.first { $0.id == exercise.machineID }
    }

    var body: some View {
        DisclosureGroup {
            Stepper("Sets: \(exercise.targetSets)", value: $exercise.targetSets, in: 1...10)
            Stepper("Reps: \(exercise.targetReps)", value: $exercise.targetReps, in: 1...30)
            Stepper("Weight: \(formatWeight(exercise.targetWeight, unit: unit))",
                    value: $exercise.targetWeight,
                    in: (machine?.stackMin ?? 5)...(machine?.stackMax ?? 400),
                    step: machine?.increment ?? 5)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.machineName)
                    .font(.headline)
                Text("\(exercise.targetSets) × \(exercise.targetReps) @ \(formatWeight(exercise.targetWeight, unit: unit))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
