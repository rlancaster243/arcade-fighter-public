import XCTest
@testable import FightCore

final class TMatchMetadataResolverTests: XCTestCase {
    func testCompositeMetadataPerFighterSlot() {
        var a = FighterDef(id: "a", displayName: "A", gamePlan: "t")
        a.moves = [MoveDef(id: "lp", name: "LP", meterGain: 50, hitstop: 4)]
        var b = FighterDef(id: "b", displayName: "B", gamePlan: "t")
        b.moves = [MoveDef(id: "lp", name: "LP", meterGain: 90, hitstop: 11)]
        let resolver = MatchMoveMetadataResolver(fighterDefs: [a, b])
        var snap = SimulationBootstrap.greyboxMatch()
        snap.fighterIDs = ["a", "b"]
        snap.events = [
            GameEvent(kind: .hit, tick: 1, attacker: .p1, defender: .p2, moveID: "lp", damage: 10),
            GameEvent(kind: .hit, tick: 1, attacker: .p2, defender: .p1, moveID: "lp", damage: 10),
        ]
        MeterRules.applyEvents(snapshot: &snap, metadata: resolver)
        XCTAssertGreaterThan(snap.fighters[0].meter, 0)
        XCTAssertGreaterThan(snap.fighters[1].meter, 0)
        XCTAssertNotEqual(snap.fighters[0].meter, snap.fighters[1].meter)

        var hitstopSnap = snap
        hitstopSnap.rules.hitstopRemaining = 0
        HitstopRules.applyEvents(snapshot: &hitstopSnap, metadata: resolver)
        XCTAssertEqual(hitstopSnap.rules.hitstopRemaining, 11)
    }
}