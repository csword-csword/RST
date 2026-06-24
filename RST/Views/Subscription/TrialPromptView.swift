import SwiftUI

/// Shown when an un-subscribed user picks their first machine: they can claim it
/// as their one free machine, or go straight to a subscription.
struct TrialPromptView: View {
    let machineName: String
    var onClaim: () -> Void
    var onSubscribe: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "gift.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.accentGradient)
            Text("Try Pinpoint free")
                .font(.title.bold())
            Text("You can use Pinpoint free on **one machine**. Make **\(machineName)** your free machine?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Text("You'll need Pinpoint Pro to track any other machine. You can change your free machine later in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                Button("Use \(machineName) as my free machine") {
                    onClaim(); dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("See Pinpoint Pro") {
                    onSubscribe(); dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("Cancel") { dismiss() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }
}
