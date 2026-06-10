import SwiftUI

/// Step 2: point the camera at the machine; the (stubbed) vision model
/// identifies what kind of equipment it is.
struct MachineScanView: View {
    @Environment(\.equipmentClassifier) private var classifier
    let candidates: [Machine]
    let planned: TemplateExercise?
    var onConfirm: (Machine) -> Void

    @State private var detection: EquipmentDetection?
    @State private var isScanning = true
    @State private var scanID = UUID()
    @State private var showManualPicker = false

    var body: some View {
        ZStack {
            CameraPreview()
                .ignoresSafeArea()

            VStack {
                if let planned, let plannedMachine = candidates.first(where: { $0.id == planned.machineID }) {
                    Button {
                        onConfirm(plannedMachine)
                    } label: {
                        Label("Planned: \(plannedMachine.name) — use it", systemImage: "checkmark.circle")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }

                Spacer()

                viewfinder

                Spacer()

                bottomPanel
            }
            .padding()
        }
        .task(id: scanID) { await scan() }
        .sheet(isPresented: $showManualPicker) {
            MachinePickerView(machines: candidates) { machine in
                onConfirm(machine)
            }
        }
    }

    private var viewfinder: some View {
        RoundedRectangle(cornerRadius: 24)
            .strokeBorder(isScanning ? Color.white.opacity(0.6) : Theme.accent, lineWidth: 3)
            .frame(width: 260, height: 260)
            .overlay {
                if isScanning {
                    VStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Identifying machine…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .animation(.easeInOut, value: isScanning)
    }

    @ViewBuilder
    private var bottomPanel: some View {
        VStack(spacing: 12) {
            if let detection {
                VStack(spacing: 4) {
                    Text(detection.machine.name)
                        .font(.title2.bold())
                    Text("\(detection.machine.category) · \(Int(detection.confidence * 100))% confidence")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .card()

                Button("Confirm Machine") { onConfirm(detection.machine) }
                    .buttonStyle(PrimaryButtonStyle())

                HStack(spacing: 12) {
                    Button("Rescan") { scanID = UUID() }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("Pick Manually") { showManualPicker = true }
                        .buttonStyle(SecondaryButtonStyle())
                }
            } else {
                Button("Pick Manually") { showManualPicker = true }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private func scan() async {
        isScanning = true
        detection = nil
        if let result = try? await classifier.classify(from: candidates) {
            withAnimation(.snappy) {
                detection = result
                isScanning = false
            }
        }
    }
}
