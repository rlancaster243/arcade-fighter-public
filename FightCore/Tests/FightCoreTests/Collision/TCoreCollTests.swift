import XCTest
@testable import FightCore

/// T-CORE-COLL — box math, push separation, stage bounds, hit vs hurt overlap.
final class TCoreCollTests: XCTestCase {
    func testBoxMirroringFlipsHorizontalExtents() {
        let box = Hitbox(x: 10, y: -40, w: 20, h: 40)
        let right = BoxMath.worldBox(anchorX: 0, anchorY: 0, box: box, facingRight: true)
        let left = BoxMath.worldBox(anchorX: 0, anchorY: 0, box: box, facingRight: false)
        XCTAssertEqual(right.left / BoxMath.scale, 10)
        XCTAssertEqual(right.right / BoxMath.scale, 30)
        XCTAssertEqual(left.left / BoxMath.scale, -30)
        XCTAssertEqual(left.right / BoxMath.scale, -10)
    }

    func testPushSeparationIncreasesDistance() throws {
        let ctx = try CollisionTestSupport.pairContext()
        var resolver = CollisionResolver(context: ctx)
        var snap = CollisionTestSupport.snapshot(
            p1: CollisionTestSupport.standing(at: 0, facingRight: true),
            p2: CollisionTestSupport.standing(at: 0, facingRight: false)
        )
        let before = abs(snap.fighters[0].position.x.raw - snap.fighters[1].position.x.raw)
        resolver.resolveMovement(snapshot: &snap)
        let after = abs(snap.fighters[0].position.x.raw - snap.fighters[1].position.x.raw)
        XCTAssertGreaterThan(after, before)
    }

    func testStageBoundsClamp() throws {
        let ctx = try CollisionTestSupport.pairContext()
        var resolver = CollisionResolver(context: ctx)
        var snap = CollisionTestSupport.snapshot(
            p1: CollisionTestSupport.standing(at: -500, facingRight: true),
            p2: CollisionTestSupport.standing(at: 80, facingRight: false)
        )
        resolver.resolveMovement(snapshot: &snap)
        let leftEdge = snap.fighters[0].position.x.raw + (-20 * BoxMath.scale)
        XCTAssertGreaterThanOrEqual(leftEdge, StageBounds.playLeftPx * BoxMath.scale)
    }

    func testHitOverlapsHurtAndDealsDamage() throws {
        let ctx = try CollisionTestSupport.pairContext()
        var resolver = CollisionResolver(context: ctx)
        let attacker = CollisionTestSupport.attacking(
            moveID: "norm_lp",
            stateTick: 3,
            positionX: 0,
            facingRight: true
        )
        var snap = CollisionTestSupport.snapshot(
            p1: attacker,
            p2: CollisionTestSupport.standing(at: 10, facingRight: false, kind: .idle)
        )
        resolver.resolveHits(snapshot: &snap)
        XCTAssertEqual(snap.fighters[1].health, 920)
        XCTAssertTrue(snap.events.contains { $0.kind == .hit })
    }
}