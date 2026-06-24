import SwiftUI

struct RootView: View {
    @Environment(\.pinDevice) private var pinDevice
    @Environment(\.subscriptions) private var subscriptions
    @AppStorage("didOnboard") private var didOnboard = false
    @State private var showOnboarding = false

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            TemplatesView()
                .tabItem { Label("Builder", systemImage: "square.grid.2x2.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .fontDesign(.rounded)
        // Begin scanning for the smart pin and load subscription state at launch.
        .task { await pinDevice.connect() }
        .task { subscriptions.start() }
        .onAppear {
            if !didOnboard { showOnboarding = true }
        }
        .sheet(isPresented: $showOnboarding, onDismiss: { didOnboard = true }) {
            OnboardingView()
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Workout.self, WorkoutTemplate.self], inMemory: true)
}
