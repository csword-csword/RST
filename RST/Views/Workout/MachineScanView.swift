import SwiftUI

/// Step 2: point the camera at the machine's name label; on-device OCR reads the
/// text and matches it to a machine in the active gym's catalog. On the
/// simulator (no camera), a mock classifier stands in so the flow is demoable.
struct MachineScanView: View {
    @Environment(\.equipmentClassifier) private var classifier
    let candidates: [Machine]
    let planned: TemplateExercise?
    var onConfirm: (Machine) -> Void

    @State private var detection: EquipmentDetection?
    @State private var fromLabel = false
    @State private var showManualPicker = false

    var body: some View {
        ZStack {
            LabelScannerView { text in
                if let match = EquipmentTextMatcher.bestMatch(in: text, candidates: candidates) {
                    if detection?.machine.id != match.machine.id {
                        withAnimation(.snappy) {
                            detection = match
                            fromLabel = true
                        }
                    }
                }
            }
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
        .task { await simulatorFallback() }
        .sheet(isPresented: $showManualPicker) {
            MachinePickerView(machines: candidates) { machine in
                onConfirm(machine)
            }
        }
    }

    private var viewfinder: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(detection == nil ? Color.white.opacity(0.6) : Theme.accent, lineWidth: 3)
                .frame(width: 280, height: 150)
                .overlay {
                    if detection == nil {
                        VStack(spacing: 8) {
                            Image(systemName: "text.viewfinder").font(.title)
                            Text("Point at the machine's name label")
                                .font(.subheadline.bold())
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal)
                    }
                }
                .animation(.easeInOut, value: detection == nil)
            if detection == nil {
                Text("e.g. the placard that reads “LAT PULLDOWN”")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    @ViewBuilder
    private var bottomPanel: some View {
        VStack(spacing: 12) {
            if let detection {
                VStack(spacing: 4) {
                    Text(detection.machine.name)
                        .font(.title2.bold())
                    Text(fromLabel
                         ? "Read from label · \(detection.machine.category)"
                         : "\(detection.machine.category) · \(Int(detection.confidence * 100))% confidence")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .card()

                Button("Confirm Machine") { onConfirm(detection.machine) }
                    .buttonStyle(PrimaryButtonStyle())

                HStack(spacing: 12) {
                    Button("Rescan") {
                        withAnimation { detection = nil; fromLabel = false }
                    }
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

    /// On the simulator there's no camera/OCR, so synthesize a detection with the
    /// mock classifier after a moment to keep the flow demoable. No-op on device.
    private func simulatorFallback() async {
        #if targetEnvironment(simulator)
        try? await Task.sleep(for: .seconds(2))
        guard detection == nil else { return }
        if let result = try? await classifier.classify(from: candidates) {
            withAnimation(.snappy) { detection = result; fromLabel = false }
        }
        #endif
    }
}
