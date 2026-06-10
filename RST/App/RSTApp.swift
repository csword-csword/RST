import SwiftUI
import SwiftData

@main
struct RSTApp: App {
    // Dependency injection point for hardware + ML integrations.
    // When the smart-pin API and vision models are ready, swap the mock
    // implementations below for real ones — the rest of the app only
    // talks to the protocols.
    @State private var catalogStore = EquipmentCatalogStore()
    @State private var locationService = LocationService()
    @State private var pinDevice = MockPinDevice()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.catalogStore, catalogStore)
                .environment(\.locationService, locationService)
                .environment(\.pinDevice, pinDevice)
                .environment(\.equipmentClassifier, MockEquipmentClassifier())
                .environment(\.stackReader, MockWeightStackReader())
        }
        .modelContainer(for: [Workout.self, WorkoutTemplate.self])
    }
}
