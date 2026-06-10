import SwiftUI

/// Step 3: point the camera at the weight stack; the (stubbed) reader infers
/// the loaded weight from the smart pin's position.
struct StackScanView: View {
    @Environment(\.stackReader) private var stackReader
    let machine: Machine
    let selectedWeight: Double
    let unit: WeightUnit
    var onConfirm: (Double) -> Void

    @State private var reading: StackReading?
    @State private var confirmedWeight: Double = 0
    @State private var isScanning = true
    @State private var scanID = UUID()

    private var mismatch: Bool {
        guard let reading else { return false }
        return reading.weight != machine.snappedWeight(selectedWeight)
    }

    var body: some View {
        ZStack {
            CameraPreview()
                .ignoresSafeArea()

            VStack {
                Text(machine.name)
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)

                Spacer()

                viewfinder

                Spacer()

                bottomPanel
            }
            .padding()
        }
        .task(id: scanID) { await scan() }
    }

    private var viewfinder: some View {
        RoundedRectangle(cornerRadius: 24)
            .strokeBorder(isScanning ? Color.white.opacity(0.6) : Theme.accent, lineWidth: 3)
            .frame(width: 200, height: 300)
            .overlay {
                if isScanning {
                    VStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Reading stack…")
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
            if let reading {
                VStack(spacing: 6) {
                    Text(formatWeight(confirmedWeight, unit: unit))
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.accentGradient)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: confirmedWeight)
                    Text("Pin detected · \(Int(reading.confidence * 100))% confidence")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if mismatch {
                        Label("Differs from your target of \(formatWeight(machine.snappedWeight(selectedWeight), unit: unit))",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.warning)
                    }
                    Stepper("Adjust",
                            value: $confirmedWeight,
                            in: machine.stackMin...machine.stackMax,
                            step: machine.increment)
                        .font(.subheadline)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity)
                .card()

                Button("Confirm \(formatWeight(confirmedWeight, unit: unit)) — Start Lifting") {
                    onConfirm(confirmedWeight)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Rescan Stack") { scanID = UUID() }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private func scan() async {
        isScanning = true
        reading = nil
        if let result = try? await stackReader.readStack(for: machine, selectedWeight: selectedWeight) {
            withAnimation(.snappy) {
                reading = result
                confirmedWeight = result.weight
                isScanning = false
            }
        }
    }
}
