import XCTest
@testable import FightCore

/// T-CORE-UNBL — throws bypass guard; normal attacks respect block stance.
final class TCoreUnblTests: XCTestCase {
    func testThrowHitsBlockingOpponent() throws {
        let ctx = try CollisionTestSupport.pairContext()
        var resolver = CollisionResolver(context: ctx)
        let attacker = CollisionTestSupport.attacking(
            moveID: "throw_lp_lk",
            stateTick: 3,
            positionX: 0,
            facingRight: true
        )
        var snap = CollisionTestSupport.snapshot(
            p1: attacker,
            p2: CollisionTestSupport.standing(at: 5, facingRight: false, kind: .walkBack)
        )
        resolver.resolveHits(snapshot: &snap)
        XCTAssertTrue(snap.events.contains { $0.kind == .throwHit })
        XCTAssertEqual(snap.fighters[1].kind, .beingThrown)
    }

    func testMidAttackBlockedWhileWalkingBack() throws {
        let def = CollisionTestSupport.tinyDef(guardLevel: .mid)
        let ctx = CollisionMatchContext(fighterDefs: [def, def])
        var resolver = CollisionResolver(context: ctx)
        let attacker = CollisionTestSupport.attacking(
            moveID: "test_move",
            stateTick: 0,
            positionX: 0,
            facingRight: true
        )
        var snap = CollisionTestSupport.snapshot(
            p1: attacker,
            p2: CollisionTestSupport.standing(at: 8, facingRight: false, kind: .walkBack)
        )
        snap.fighterIDs = ["tiny", "tiny"]
        resolver.resolveHits(snapshot: &snap)
        XCTAssertTrue(snap.events.contains { $0.kind == .block })
        XCTAssertEqual(snap.fighters[1].health, 1000)
        XCTAssertEqual(snap.fighters[1].kind, .blockstunStand)
    }
}