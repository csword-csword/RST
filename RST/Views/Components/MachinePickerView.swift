import SwiftUI

/// Equipment list grouped by category, used for manual machine selection in
/// the scan flow and for adding exercises in the workout builder.
struct MachinePickerView: View {
    let machines: [Machine]
    var onSelect: (Machine) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(machines.categories, id: \.self) { category in
                    Section(category) {
                        ForEach(machines.filter { $0.category == category }) { machine in
                            Button {
                                onSelect(machine)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(machine.name)
                                        .foregroundStyle(.primary)
                                    Text(machine.muscleGroups.joined(separator: " · "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
