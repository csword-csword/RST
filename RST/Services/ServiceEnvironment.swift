import SwiftUI

// Environment keys for every service the app depends on. The app injects
// shared instances at the root (see RSTApp); these defaults exist so
// previews and tests work without explicit setup.
extension EnvironmentValues {
    @Entry var equipmentClassifier: any EquipmentClassifying = MockEquipmentClassifier()
    @Entry var stackReader: any WeightStackReading = MockWeightStackReader()
    @Entry var pinDevice: any PinDeviceService = MockPinDevice()
    @Entry var pinController: any PinControlling = MockPinController()
    @Entry var subscriptions = SubscriptionStore()
    @Entry var catalogStore = EquipmentCatalogStore()
    @Entry var locationService = LocationService()
}
