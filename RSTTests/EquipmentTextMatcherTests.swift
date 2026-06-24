import XCTest
@testable import RST

final class EquipmentTextMatcherTests: XCTestCase {
    private func machine(_ id: String, _ name: String) -> Machine {
        Machine(id: id, name: name, category: "Test", muscleGroups: [],
                stackMin: 10, stackMax: 200, increment: 10)
    }

    private var candidates: [Machine] {
        [machine("lat-pulldown", "Lat Pulldown"),
         machine("seated-row", "Seated Row"),
         machine("chest-press", "Chest Press"),
         machine("leg-press", "Leg Press")]
    }

    func testExactLabelMatches() {
        let d = EquipmentTextMatcher.bestMatch(in: ["LAT PULLDOWN"], candidates: candidates)
        XCTAssertEqual(d?.machine.id, "lat-pulldown")
        XCTAssertGreaterThan(d?.confidence ?? 0, 0.9)
    }

    func testNoisyLabelStillMatches() {
        let d = EquipmentTextMatcher.bestMatch(
            in: ["LIFE FITNESS", "Lat Pulldown", "See instructions"],
            candidates: candidates)
        XCTAssertEqual(d?.machine.id, "lat-pulldown")
    }

    func testDisambiguatesSimilarNames() {
        XCTAssertEqual(EquipmentTextMatcher.bestMatch(in: ["SEATED ROW"], candidates: candidates)?.machine.id, "seated-row")
        XCTAssertEqual(EquipmentTextMatcher.bestMatch(in: ["CHEST PRESS"], candidates: candidates)?.machine.id, "chest-press")
        XCTAssertEqual(EquipmentTextMatcher.bestMatch(in: ["LEG PRESS"], candidates: candidates)?.machine.id, "leg-press")
    }

    func testUnrelatedTextDoesNotMatch() {
        XCTAssertNil(EquipmentTextMatcher.bestMatch(in: ["EXIT", "FIRE EXTINGUISHER"], candidates: candidates))
    }

    func testEmptyTextDoesNotMatch() {
        XCTAssertNil(EquipmentTextMatcher.bestMatch(in: [], candidates: candidates))
    }
}
