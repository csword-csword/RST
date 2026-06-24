import SwiftUI

struct PaywallView: View {
    @Environment(\.subscriptions) private var subscriptions
    @Environment(\.dismiss) private var dismiss
    /// Optional context, e.g. the machine that triggered the paywall.
    var contextMessage: String?

    // Rep tracking, history, builder, and gym profiles are FREE with the pin.
    // Pro adds extras on top — update this list as Pro features ship.
    private let benefits = [
        ("square.and.arrow.up", "Export your data", "Download your full history as a spreadsheet."),
        ("icloud.fill", "Cloud backup & sync", "Your training, safe and on every device."),
        ("chart.line.uptrend.xyaxis", "Advanced insights", "Trends, PRs, and progress analytics."),
        ("sparkles", "New Pro features", "Get every Pro feature as we ship it.")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.accentGradient)
                    Text("Pinpoint Pro")
                        .font(.largeTitle.bold())
                    Text(contextMessage ?? "Rep tracking is free. Pinpoint Pro adds backup, insights, and export.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                VStack(spacing: 14) {
                    ForEach(benefits, id: \.0) { benefit in
                        HStack(spacing: 14) {
                            Image(systemName: benefit.0)
                                .font(.title3)
                                .foregroundStyle(Theme.accent)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(benefit.1).font(.headline)
                                Text(benefit.2).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(spacing: 6) {
                    Text("\(subscriptions.priceText) / year")
                        .font(.title2.bold())
                    Text("Auto-renews yearly until cancelled.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        if await subscriptions.purchase() { dismiss() }
                    }
                } label: {
                    if subscriptions.isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Text("Subscribe")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(subscriptions.isWorking)

                Button("Restore Purchases") {
                    Task {
                        await subscriptions.restore()
                        if subscriptions.isSubscribed { dismiss() }
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Theme.accent)

                disclosure
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private var disclosure: some View {
        VStack(spacing: 8) {
            Text("Payment is charged to your Apple Account at confirmation. The subscription renews automatically unless cancelled at least 24 hours before the end of the period. Manage or cancel in your Apple Account settings.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("Privacy Policy", destination: URL(string: "https://pinpoint.fitness/privacy")!)
            }
            .font(.caption2)
            .foregroundStyle(Theme.accent)
        }
    }
}
