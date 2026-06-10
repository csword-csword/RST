import XCTest
@testable import RST

final class CatalogTests: XCTestCase {
    func testBundledCatalogsLoad() {
        let store = EquipmentCatalogStore()
        XCTAssertEqual(store.catalogs.count, 3, "standard, planet-fitness and la-fitness catalogs should load")
        for catalog in store.catalogs {
            XCTAssertFalse(catalog.machines.isEmpty, "\(catalog.id) has no machines")
            for machine in catalog.machines {
                XCTAssertGreaterThan(machine.increment, 0)
                XCTAssertLessThan(machine.stackMin, machine.stackMax)
            }
        }
    }

    func testCatalogLookupFallsBack() {
        let store = EquipmentCatalogStore()
        XCTAssertEqual(store.catalog(id: "planet-fitness").id, "planet-fitness")
        XCTAssertEqual(store.catalog(id: "nonexistent").id, store.catalogs.first?.id)
    }

    func testSnappedWeight() {
        let machine = Machine(id: "test", name: "Test", category: "Test", muscleGroups: [],
                              stackMin: 10, stackMax: 200, increment: 10)
        XCTAssertEqual(machine.snappedWeight(104), 100)
        XCTAssertEqual(machine.snappedWeight(106), 110)
        XCTAssertEqual(machine.snappedWeight(0), 10, "clamps to stack minimum")
        XCTAssertEqual(machine.snappedWeight(999), 200, "clamps to stack maximum")
    }
}
