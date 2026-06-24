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
    @State private var pinController: any PinControlling

    init() {
        _pinDevice = State(initialValue: Self.makePinDevice())
        _pinController = State(initialValue: Self.makePinController())
    }

    private static func useSimulatedPin() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return UserDefaults.standard.object(forKey: "useSimulatedPin") as? Bool ?? false
        #endif
    }

    private static func makePinDevice() -> any PinDeviceService {
        useSimulatedPin() ? MockPinDevice() : MokoPinDevice()
    }

    private static func makePinController() -> any PinControlling {
        useSimulatedPin() ? MockPinController() : MokoPinController()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.catalogStore, catalogStore)
                .environment(\.locationService, locationService)
                .environment(\.pinDevice, pinDevice)
                .environment(\.pinController, pinController)
                .environment(\.equipmentClassifier, MockEquipmentClassifier())
                .environment(\.stackReader, MockWeightStackReader())
        }
        .modelContainer(for: [Workout.self, WorkoutTemplate.self])
    }
}
