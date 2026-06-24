import SwiftUI

/// First-launch walkthrough: what the pin does, the free machine, and Pro.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.subscriptions) private var subscriptions
    @State private var page = 0
    @State private var showPaywall = false

    private struct Page: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let body: String
    }

    private let pages = [
        Page(icon: "bolt.fill",
             title: "Welcome to Pinpoint",
             body: "Your smart pin tracks every rep and set automatically. Just lift — Pinpoint counts."),
        Page(icon: "antenna.radiowaves.left.and.right",
             title: "Connect your pin",
             body: "Pop the Pinpoint pin into any weight stack. The app finds it over Bluetooth and reads your weight, reps, and sets."),
        Page(icon: "checkmark.seal.fill",
             title: "Free with your pin",
             body: "Rep tracking, history, and workout building are free. Pinpoint Pro is optional — it adds data export, cloud backup, and deeper insights.")
    ]

    var body: some View {
        VStack {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, item in
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: item.icon)
                            .font(.system(size: 64))
                            .foregroundStyle(Theme.accentGradient)
                        Text(item.title)
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text(item.body)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack(spacing: 12) {
                if page == pages.count - 1 {
                    Button("Get Started") { dismiss() }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("See Pinpoint Pro") { showPaywall = true }
                        .font(.subheadline)
                        .foregroundStyle(Theme.accent)
                } else {
                    Button("Continue") { withAnimation { page += 1 } }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Skip") { dismiss() }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}
