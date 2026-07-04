import XCTest
@testable import RST

final class EquipmentTextMatcherTests: XCTestCase {
    private func machine(_ id: String, _ name: String, aliases: [String] = []) -> Machine {
        Machine(id: id, name: name, category: "Test", muscleGroups: [],
                stackMin: 10, stackMax: 200, increment: 10,
                aliases: aliases.isEmpty ? nil : aliases)
    }

    private var candidates: [Machine] {
        [machine("lat-pulldown", "Lat Pulldown",
                 aliases: ["iso-lateral front lat pulldown", "pulldown", "lat machine"]),
         machine("seated-row", "Seated Row", aliases: ["low row", "cable row"]),
         machine("chest-press", "Chest Press"),
         machine("leg-press", "Leg Press")]
    }

    func testExactLabelMatches() {
        let d = EquipmentTextMatcher.bestMatch(strings: ["LAT PULLDOWN"], candidates: candidates)
        XCTAssertEqual(d?.machine.id, "lat-pulldown")
        XCTAssertGreaterThan(d?.confidence ?? 0, 0.85)
    }

    func testMatchesViaManufacturerAlias() {
        let d = EquipmentTextMatcher.bestMatch(strings: ["ISO-LATERAL FRONT LAT PULLDOWN"], candidates: candidates)
        XCTAssertEqual(d?.machine.id, "lat-pulldown")
    }

    func testMultiLineLabelPicksTitleNotDescription() {
        // Big title line + small instructions line: title should win.
        let lines = [
            RecognizedLine(text: "LAT PULLDOWN", prominence: 0.9),
            RecognizedLine(text: "Sit with the thigh pads snug and pull the bar to your chest.", prominence: 0.18),
            RecognizedLine(text: "Targets the back and arms.", prominence: 0.16)
        ]
        XCTAssertEqual(EquipmentTextMatcher.bestMatch(in: lines, candidates: candidates)?.machine.id, "lat-pulldown")
    }

    func testDisambiguatesSimilarNames() {
        XCTAssertEqual(EquipmentTextMatcher.bestMatch(strings: ["SEATED ROW"], candidates: candidates)?.machine.id, "seated-row")
        XCTAssertEqual(EquipmentTextMatcher.bestMatch(strings: ["CHEST PRESS"], candidates: candidates)?.machine.id, "chest-press")
        XCTAssertEqual(EquipmentTextMatcher.bestMatch(strings: ["LEG PRESS"], candidates: candidates)?.machine.id, "leg-press")
    }

    func testUnrelatedTextDoesNotMatch() {
        XCTAssertNil(EquipmentTextMatcher.bestMatch(strings: ["EXIT", "FIRE EXTINGUISHER"], candidates: candidates))
    }

    func testEmptyTextDoesNotMatch() {
        XCTAssertNil(EquipmentTextMatcher.bestMatch(strings: [], candidates: candidates))
    }
}
