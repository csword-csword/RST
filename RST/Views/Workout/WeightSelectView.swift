import SwiftUI

/// Step 1: pick the weight you're about to lift.
struct WeightSelectView: View {
    @Binding var weight: Double
    let planned: TemplateExercise?
    let unit: WeightUnit
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            if let planned {
                VStack(spacing: 4) {
                    Text("Up next: \(planned.machineName)")
                        .font(.headline)
                    Text("\(planned.targetSets) sets × \(planned.targetReps) reps @ \(formatWeight(planned.targetWeight, unit: unit))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .card()
            }

            VStack(spacing: 8) {
                Text(formatWeight(weight, unit: unit))
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.accentGradient)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: weight)
                Text("TARGET WEIGHT")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .tracking(2)
            }

            HStack(spacing: 24) {
                adjustButton(symbol: "minus", amount: -5)
                adjustButton(symbol: "plus", amount: 5)
            }

            Slider(value: $weight, in: 10...400, step: 5)
                .tint(Theme.accent)
                .padding(.horizontal)

            Spacer()

            Button("Next: Scan Machine", action: onNext)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal)
                .padding(.bottom, 12)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    private func adjustButton(symbol: String, amount: Double) -> some View {
        Button {
            weight = min(max(weight + amount, 10), 400)
        } label: {
            Image(systemName: symbol)
                .font(.title2.bold())
                .frame(width: 64, height: 64)
                .background(Theme.card, in: Circle())
                .overlay(Circle().strokeBorder(Theme.accent.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
