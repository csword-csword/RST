import Foundation
import Observation

/// Loads the bundled equipment catalogs: the generic standard catalog plus
/// chain-specific ones (Planet Fitness, LA Fitness).
@Observable
final class EquipmentCatalogStore {
    private(set) var catalogs: [EquipmentCatalog] = []

    /// The universal machine taxonomy used for facility-agnostic recognition and
    /// the manual picker — works at any gym, not just the configured profile.
    private(set) var master = EquipmentCatalog(id: "master", name: "All Machines", machines: [])

    init(bundle: Bundle = .main) {
        let names = ["master", "standard", "planet-fitness", "la-fitness"]
        let decoder = JSONDecoder()
        let loaded: [EquipmentCatalog] = names.compactMap { name in
            guard let url = bundle.url(forResource: name, withExtension: "json"),
                  let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(EquipmentCatalog.self, from: data)
        }
        master = loaded.first { $0.id == "master" } ?? master
        // The master taxonomy is for recognition; the gym profiles drive the
        // builder, so keep them as the user-selectable catalogs.
        catalogs = loaded.filter { $0.id != "master" }
    }

    func catalog(id: String) -> EquipmentCatalog {
        catalogs.first { $0.id == id }
            ?? catalogs.first
            ?? EquipmentCatalog(id: "empty", name: "No Catalog", machines: [])
    }
}
