import SwiftUI

/// Connected-mode pin setup: first-time connection, change connection password,
/// and reset the battery gauge after a battery swap. Backed by `PinControlling`
/// (real GATT on device, simulated in the simulator / demos).
struct PinSetupView: View {
    @Environment(\.pinController) private var controller

    @State private var password = MokoControlProtocol.defaultPassword
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var busy = false
    @State private var alert: AlertInfo?

    private var isConnected: Bool { controller.state == .connected }

    var body: some View {
        Form {
            connectionSection
            if isConnected {
                if !MokoControlProtocol.isConfigured {
                    Section {
                        Label(PinControlError.protocolNotConfigured.errorDescription ?? "",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Theme.warning)
                    }
                }
                changePasswordSection
                batterySection
                if !controller.discoveredCharacteristics.isEmpty {
                    discoveredSection
                }
            }
        }
        .navigationTitle("Pin Setup")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(busy)
        .alert(item: $alert) { info in
            Alert(title: Text(info.title), message: Text(info.message), dismissButton: .default(Text("OK")))
        }
    }

    // MARK: - Sections

    private var connectionSection: some View {
        Section {
            LabeledContent("Status") {
                Label(statusText, systemImage: statusIcon).foregroundStyle(statusColor)
            }
            if let info = controller.connectedInfo {
                LabeledContent("Sensor", value: info.name)
                LabeledContent("Tag ID", value: info.tagID.isEmpty ? "—" : info.tagID)
                if let battery = info.batteryDescription {
                    LabeledContent("Battery", value: battery)
                }
            }
            if isConnected {
                Button("Disconnect", role: .destructive) { controller.disconnect() }
            } else {
                SecureField("Connection password", text: $password)
                    .textContentType(.password)
                Button("Connect") { run { try await controller.connect(password: password) } }
                    .disabled(password.isEmpty)
            }
        } header: {
            Text("Connection")
        } footer: {
            Text("Wake the pin (move it) and keep it nearby. Default password is \(MokoControlProtocol.defaultPassword).")
        }
    }

    private var changePasswordSection: some View {
        Section {
            SecureField("New password", text: $newPassword)
            SecureField("Confirm new password", text: $confirmPassword)
            Button("Change Password") {
                guard newPassword == confirmPassword else {
                    alert = AlertInfo(title: "Passwords don't match", message: "Re-enter the new password.")
                    return
                }
                run {
                    try await controller.changePassword(current: password, new: newPassword)
                    await MainActor.run {
                        password = newPassword
                        newPassword = ""; confirmPassword = ""
                        alert = AlertInfo(title: "Password changed", message: "Use the new password next time you connect.")
                    }
                }
            }
            .disabled(newPassword.count < 4 || newPassword.count > 16)
        } header: {
            Text("Change Password")
        } footer: {
            Text("4–16 characters. You'll need this password to connect to the pin.")
        }
    }

    private var batterySection: some View {
        Section {
            Button("Reset Battery to 100%") {
                run {
                    try await controller.resetBatteryGauge()
                    await MainActor.run {
                        alert = AlertInfo(title: "Battery reset", message: "The gauge now reads 100%.")
                    }
                }
            }
        } header: {
            Text("Replace Battery")
        } footer: {
            Text("After installing a fresh, fully-charged battery, reset the gauge so the pin reports the battery level starting from 100%.")
        }
    }

    private var discoveredSection: some View {
        Section("Discovered Characteristics") {
            ForEach(controller.discoveredCharacteristics, id: \.self) { name in
                Text(name).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func run(_ work: @escaping () async throws -> Void) {
        busy = true
        Task {
            defer { busy = false }
            do { try await work() }
            catch {
                alert = AlertInfo(title: "Couldn't complete",
                                  message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
        }
    }

    private var statusText: String {
        switch controller.state {
        case .idle: return "Disconnected"
        case .scanning: return "Scanning…"
        case .connecting: return "Connecting…"
        case .authenticating: return "Authenticating…"
        case .connected: return "Connected"
        case .failed(let message): return message
        }
    }

    private var statusIcon: String {
        switch controller.state {
        case .connected: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .idle: return "antenna.radiowaves.left.and.right.slash"
        default: return "antenna.radiowaves.left.and.right"
        }
    }

    private var statusColor: Color {
        switch controller.state {
        case .connected: return Theme.accent
        case .failed: return Theme.warning
        case .idle: return .secondary
        default: return Theme.warning
        }
    }
}

private struct AlertInfo: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
