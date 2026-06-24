import SwiftUI

struct SettingsView: View {
    @Environment(\.catalogStore) private var catalogStore
    @Environment(\.locationService) private var locationService
    @Environment(\.pinDevice) private var pinDevice
    @AppStorage("gymProfileID") private var gymProfileID = "standard"
    @AppStorage("weightUnit") private var weightUnitRaw = WeightUnit.lb.rawValue
    @AppStorage("useSimulatedPin") private var useSimulatedPin = false

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
                        Label(statusText, systemImage: statusIcon)
                            .foregroundStyle(statusColor)
                    }
                    if let info = pinDevice.deviceInfo {
                        LabeledContent("Sensor", value: info.name)
                        LabeledContent("Tag ID", value: info.tagID.isEmpty ? "—" : info.tagID)
                        if let battery = info.batteryDescription {
                            LabeledContent("Battery", value: battery)
                        }
                        if let rssi = info.rssi {
                            LabeledContent("Signal", value: "\(rssi) dBm")
                        }
                    }
                } header: {
                    Text("Smart Pin Device")
                } footer: {
                    Text("RST scans for the MOKO M1Pro sensor's advertisement and counts reps from its broadcast acceleration — no pairing needed. Configure the sensor with the MOKO app (see SENSOR_SETUP.md).")
                }

                Section {
                    NavigationLink {
                        PinSetupView()
                    } label: {
                        Label("Connect & Configure Pin", systemImage: "antenna.radiowaves.left.and.right")
                    }
                } footer: {
                    Text("Connect to the pin to change its password or reset the battery gauge after a swap.")
                }

                Section {
                    Toggle("Use simulated pin", isOn: $useSimulatedPin)
                } footer: {
                    Text("Run with a simulated pin instead of real Bluetooth hardware — useful for demos. Relaunch the app to apply.")
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

    private var statusText: String {
        switch pinDevice.connectionState {
        case .connected: return "Connected"
        case .scanning: return "Scanning…"
        case .disconnected: return "Disconnected"
        }
    }

    private var statusIcon: String {
        switch pinDevice.connectionState {
        case .connected: return "dot.radiowaves.left.and.right"
        case .scanning: return "antenna.radiowaves.left.and.right"
        case .disconnected: return "antenna.radiowaves.left.and.right.slash"
        }
    }

    private var statusColor: Color {
        switch pinDevice.connectionState {
        case .connected: return Theme.accent
        case .scanning: return Theme.warning
        case .disconnected: return .secondary
        }
    }
}
