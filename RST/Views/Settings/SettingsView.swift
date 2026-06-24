import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.catalogStore) private var catalogStore
    @Environment(\.locationService) private var locationService
    @Environment(\.pinDevice) private var pinDevice
    @Environment(\.subscriptions) private var subscriptions
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @AppStorage("gymProfileID") private var gymProfileID = "standard"
    @AppStorage("weightUnit") private var weightUnitRaw = WeightUnit.lb.rawValue
    @AppStorage("useSimulatedPin") private var useSimulatedPin = false
    @AppStorage("defaultRestSeconds") private var defaultRestSeconds = 90
    @AppStorage("voiceCoachEnabled") private var voiceCoachEnabled = false
    @State private var sheet: SettingsSheet?

    private var unit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lb }

    private enum SettingsSheet: Identifiable {
        case paywall
        case export(URL)
        var id: String {
            switch self {
            case .paywall: return "paywall"
            case .export(let url): return url.absoluteString
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                subscriptionSection

                Section {
                    Picker("Gym", selection: $gymProfileID) {
                        ForEach(catalogStore.catalogs) { catalog in
                            Text(catalog.name).tag(catalog.id)
                        }
                    }
                } header: {
                    Text("Gym Profile")
                } footer: {
                    Text("Machine scanning works at any gym. Chain profiles (Planet Fitness, LA Fitness) just tailor the workout builder to the machines those gyms carry.")
                }

                Section("Units") {
                    Picker("Weight unit", selection: $weightUnitRaw) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.label).tag(unit.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                workoutSection

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

                proSection

                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear { locationService.requestLocation() }
        .sheet(item: $sheet) { which in
            switch which {
            case .paywall: PaywallView()
            case .export(let url): ActivityView(items: [url])
            }
        }
    }

    @ViewBuilder
    private var workoutSection: some View {
        Section {
            Picker("Rest timer", selection: $defaultRestSeconds) {
                ForEach([60, 75, 90, 120, 150, 180], id: \.self) { secs in
                    Text("\(secs / 60):\(String(format: "%02d", secs % 60))").tag(secs)
                }
            }

            if subscriptions.isSubscribed {
                Toggle("Voice coach", isOn: $voiceCoachEnabled)
            } else {
                Button { sheet = .paywall } label: {
                    HStack {
                        Text("Voice coach").foregroundStyle(.primary)
                        Spacer()
                        ProBadge()
                    }
                }
            }
        } header: {
            Text("Workout")
        } footer: {
            Text("Rest timer counts down between sets. The voice coach (Pro) calls out reps and tells you when to start your next set — great with headphones.")
        }
    }

    @ViewBuilder
    private var proSection: some View {
        Section {
            Button {
                if subscriptions.isSubscribed {
                    if let url = WorkoutExporter.writeTempFile(from: workouts, unit: unit) {
                        sheet = .export(url)
                    }
                } else {
                    sheet = .paywall
                }
            } label: {
                HStack {
                    Label("Export Workouts (CSV)", systemImage: "square.and.arrow.up")
                    Spacer()
                    if !subscriptions.isSubscribed { ProBadge() }
                }
            }
            .disabled(workouts.isEmpty)
        } header: {
            Text("Your Data")
        } footer: {
            Text(subscriptions.isSubscribed
                 ? "Export your full workout history as a spreadsheet."
                 : "Exporting your history is a Pinpoint Pro feature.")
        }
    }

    @ViewBuilder
    private var subscriptionSection: some View {
        Section {
            LabeledContent("Plan") {
                if subscriptions.isSubscribed {
                    Label("Pinpoint Pro", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(Theme.accent)
                } else {
                    Text("Free").foregroundStyle(.secondary)
                }
            }

            if subscriptions.isSubscribed {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    Link("Manage Subscription", destination: url)
                }
            } else {
                Button("Upgrade to Pinpoint Pro") { sheet = .paywall }
                    .foregroundStyle(Theme.accent)
            }

            Button("Restore Purchases") {
                Task { await subscriptions.restore() }
            }
            .foregroundStyle(.secondary)
        } header: {
            Text("Subscription")
        } footer: {
            Text(subscriptions.isSubscribed
                 ? "Thanks for supporting Pinpoint. Manage or cancel anytime in your Apple Account."
                 : "Rep tracking and history are free with your pin. Pinpoint Pro (\(subscriptions.priceText)/year) adds extras like data export.")
        }
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
