import XCTest
@testable import AppLogic
import FightCore

final class MoveMetadataTableTests: XCTestCase {
    func testDuplicateFighterIDsDoNotTrapWhenBuildingDefs() {
        let def = FighterDef(id: "greybox", displayName: "Greybox", gamePlan: "test")
        let map = FighterDefinitionMap.keyedByFighterID(p1: def, p2: def)
        XCTAssertEqual(map.count, 1)
        XCTAssertEqual(map["greybox"]?.id, "greybox")
    }

    func testCompositeKeysDisambiguateSharedMoveIDs() throws {
        var a = FighterDef(id: "a", displayName: "A", gamePlan: "t")
        a.moves = [
            MoveDef(
                id: "lp",
                name: "LP",
                meterGain: 100,
                hitstop: 5
            ),
        ]
        var b = FighterDef(id: "b", displayName: "B", gamePlan: "t")
        b.moves = [
            MoveDef(
                id: "lp",
                name: "LP",
                meterGain: 200,
                hitstop: 9
            ),
        ]
        let table = MoveMetadataTable(fighterDefs: [a, b])
        XCTAssertEqual(table.metadata(fighterID: "a", moveID: "lp")?.meterGain, 100)
        XCTAssertEqual(table.metadata(fighterID: "b", moveID: "lp")?.meterGain, 200)
    }
}