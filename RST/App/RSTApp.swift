import SwiftUI
import SwiftData

@main
struct RSTApp: App {
    // Dependency injection point for hardware + ML integrations.
    // The equipment classifier and stack reader are still mocked; the smart pin
    // uses the real MOKO M1Pro driver on device (and the mock in the simulator
    // or when "Use simulated pin" is enabled in Settings).
    @State private var catalogStore = EquipmentCatalogStore()
    @State private var locationService = LocationService()
    @State private var pinDevice: any PinDeviceService

    init() {
        _pinDevice = State(initialValue: Self.makePinDevice())
    }

    private static func makePinDevice() -> any PinDeviceService {
        #if targetEnvironment(simulator)
        return MockPinDevice()
        #else
        let simulated = UserDefaults.standard.object(forKey: "useSimulatedPin") as? Bool ?? false
        return simulated ? MockPinDevice() : MokoPinDevice()
        #endif
    }

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
