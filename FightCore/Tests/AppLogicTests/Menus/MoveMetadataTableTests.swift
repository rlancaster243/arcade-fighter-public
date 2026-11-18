import XCTest
@testable import AppLogic
import FightCore

final class MoveMetadataTableTests: XCTestCase {
    func testRosterPickMapUsesPickIDsNotBundleIDs() {
        let greybox = FighterDef(id: "greybox", displayName: "Greybox", gamePlan: "test")
        let map = FighterDefinitionMap.keyedByRosterPick(
            p1PickID: "missing_roster_id",
            p1: greybox,
            p2PickID: "greybox",
            p2: greybox
        )
        XCTAssertEqual(map["missing_roster_id"]?.id, "missing_roster_id")
        XCTAssertEqual(map["greybox"]?.id, "greybox")
        XCTAssertEqual(map.count, 2)
    }

    func testCompositeKeysDisambiguateSharedMoveIDs() {
        var a = FighterDef(id: "a", displayName: "A", gamePlan: "t")
        a.moves = [MoveDef(id: "lp", name: "LP", meterGain: 100, hitstop: 5)]
        var b = FighterDef(id: "b", displayName: "B", gamePlan: "t")
        b.moves = [MoveDef(id: "lp", name: "LP", meterGain: 200, hitstop: 9)]
        let table = MoveMetadataTable(fighterDefs: [a, b])
        var snap = SimulationBootstrap.greyboxMatch()
        snap.fighterIDs = ["a", "b"]
        XCTAssertEqual(table.resolver.metadata(for: .p1, moveID: "lp", in: snap).meterGain, 100)
        XCTAssertEqual(table.resolver.metadata(for: .p2, moveID: "lp", in: snap).meterGain, 200)
    }
}