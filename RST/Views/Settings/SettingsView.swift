import SwiftUI

struct SettingsView: View {
    @Environment(\.catalogStore) private var catalogStore
    @Environment(\.locationService) private var locationService
    @AppStorage("gymProfileID") private var gymProfileID = "standard"
    @AppStorage("weightUnit") private var weightUnitRaw = WeightUnit.lb.rawValue

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Gym", selection: $gymProfileID) {
                        ForEach(catalogStore.catalogs) { catalog in
                            Text(catalog.name).tag(catalog.id)
                        }
                    }
                } header: {
                    Text("Gym Profile")
                } footer: {
                    Text("Chain profiles (Planet Fitness, LA Fitness) limit equipment detection and the workout builder to the machines those gyms carry.")
                }

                Section("Units") {
                    Picker("Weight unit", selection: $weightUnitRaw) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.label).tag(unit.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    LabeledContent("Status") {
                        Label("Simulated", systemImage: "dot.radiowaves.left.and.right")
                            .foregroundStyle(Theme.warning)
                    }
                } header: {
                    Text("Smart Pin Device")
                } footer: {
                    Text("The smart pin hardware API isn't available yet. Machine detection, stack reading, and rep tracking are simulated; the real device SDK plugs into the same interfaces.")
                }

                Section {
                    LabeledContent("Location") {
                        Text(locationService.current?.placeName ?? "Not available")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Used to record where each workout took place.")
                }

                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear { locationService.requestLocation() }
    }
}
