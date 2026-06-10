import SwiftUI

struct RootView: View {
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
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Workout.self, WorkoutTemplate.self], inMemory: true)
}
