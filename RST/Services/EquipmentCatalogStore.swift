import Foundation
import Observation

/// Loads the bundled equipment catalogs: the generic standard catalog plus
/// chain-specific ones (Planet Fitness, LA Fitness).
@Observable
final class EquipmentCatalogStore {
    private(set) var catalogs: [EquipmentCatalog] = []

    init(bundle: Bundle = .main) {
        let names = ["standard", "planet-fitness", "la-fitness"]
        let decoder = JSONDecoder()
        catalogs = names.compactMap { name in
            guard let url = bundle.url(forResource: name, withExtension: "json"),
                  let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(EquipmentCatalog.self, from: data)
        }
    }

    func catalog(id: String) -> EquipmentCatalog {
        catalogs.first { $0.id == id }
            ?? catalogs.first
            ?? EquipmentCatalog(id: "empty", name: "No Catalog", machines: [])
    }
}
