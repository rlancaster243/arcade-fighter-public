import XCTest
@testable import FightCore

/// T-CORE-FEEL — hitstop, pushback, chip, trades, guard levels.
final class TCoreFeelTests: XCTestCase {
    func testHitstopAppliedOnHit() throws {
        let ctx = try CollisionTestSupport.pairContext()
        var resolver = CollisionResolver(context: ctx)
        var snap = CollisionTestSupport.snapshot(
            p1: CollisionTestSupport.attacking(moveID: "norm_lp", stateTick: 3, positionX: 0, facingRight: true),
            p2: CollisionTestSupport.standing(at: 10, facingRight: false)
        )
        resolver.resolveHits(snapshot: &snap)
        XCTAssertEqual(snap.rules.hitstopRemaining, 6)
    }

    func testPushbackOnHit() throws {
        let ctx = try CollisionTestSupport.pairContext()
        var resolver = CollisionResolver(context: ctx)
        var snap = CollisionTestSupport.snapshot(
            p1: CollisionTestSupport.attacking(moveID: "norm_lp", stateTick: 3, positionX: 0, facingRight: true),
            p2: CollisionTestSupport.standing(at: 10, facingRight: false)
        )
        let before = snap.fighters[1].position.x.raw
        resolver.resolveHits(snapshot: &snap)
        XCTAssertGreaterThan(snap.fighters[1].position.x.raw, before)
    }

    func testChipOnBlockedSpecialNotBelowOneHP() throws {
        let def = CollisionTestSupport.tinyDef(guardLevel: .mid, inputKind: .special, chip: 50, damage: 200)
        let ctx = CollisionMatchContext(fighterDefs: [def, def])
        var resolver = CollisionResolver(context: ctx)
        var snap = CollisionTestSupport.snapshot(
            p1: CollisionTestSupport.attacking(moveID: "test_move", stateTick: 0, positionX: 0, facingRight: true),
            p2: CollisionTestSupport.standing(at: 8, facingRight: false, kind: .walkBack)
        )
        snap.fighterIDs = ["tiny", "tiny"]
        snap.fighters[1].health = 1
        resolver.resolveHits(snapshot: &snap)
        XCTAssertEqual(snap.fighters[1].health, 1)
        XCTAssertTrue(snap.events.contains { $0.kind == .block })
    }

    func testHighAttackMissesCrouch() throws {
        let def = CollisionTestSupport.tinyDef(guardLevel: .high)
        let ctx = CollisionMatchContext(fighterDefs: [def, def])
        var resolver = CollisionResolver(context: ctx)
        var snap = CollisionTestSupport.snapshot(
            p1: CollisionTestSupport.attacking(moveID: "test_move", stateTick: 0, positionX: 0, facingRight: true),
            p2: CollisionTestSupport.standing(at: 8, facingRight: false, kind: .crouch)
        )
        snap.fighterIDs = ["tiny", "tiny"]
        resolver.resolveHits(snapshot: &snap)
        XCTAssertTrue(snap.events.isEmpty)
        XCTAssertEqual(snap.fighters[1].health, 1000)
    }

    func testLowAttackNeedsCrouchBlock() throws {
        let def = CollisionTestSupport.tinyDef(guardLevel: .low)
        let ctx = CollisionMatchContext(fighterDefs: [def, def])
        var resolver = CollisionResolver(context: ctx)
        var snap = CollisionTestSupport.snapshot(
            p1: CollisionTestSupport.attacking(moveID: "test_move", stateTick: 0, positionX: 0, facingRight: true),
            p2: CollisionTestSupport.standing(at: 8, facingRight: false, kind: .walkBack)
        )
        snap.fighterIDs = ["tiny", "tiny"]
        resolver.resolveHits(snapshot: &snap)
        XCTAssertEqual(snap.fighters[1].health, 900)

        snap = CollisionTestSupport.snapshot(
            p1: CollisionTestSupport.attacking(moveID: "test_move", stateTick: 0, positionX: 0, facingRight: true),
            p2: CollisionTestSupport.standing(at: 8, facingRight: false, kind: .crouch)
        )
        snap.fighterIDs = ["tiny", "tiny"]
        resolver.resolveHits(snapshot: &snap)
        XCTAssertEqual(snap.fighters[1].kind, .blockstunCrouch)
    }

    func testTradeDamagesBothFighters() throws {
        let ctx = try CollisionTestSupport.pairContext()
        var resolver = CollisionResolver(context: ctx)
        var snap = CollisionTestSupport.snapshot(
            p1: CollisionTestSupport.attacking(moveID: "norm_lp", stateTick: 3, positionX: 0, facingRight: true),
            p2: CollisionTestSupport.attacking(moveID: "norm_lp", stateTick: 3, positionX: 10, facingRight: false)
        )
        resolver.resolveHits(snapshot: &snap)
        XCTAssertEqual(snap.fighters[0].health, 920)
        XCTAssertEqual(snap.fighters[1].health, 920)
        XCTAssertEqual(snap.events.filter { $0.kind == .hit }.count, 2)
    }
}