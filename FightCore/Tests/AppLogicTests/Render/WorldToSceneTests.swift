import XCTest
import FightCore
@testable import AppLogic

/// The sim is y-down with x centred on the stage; SpriteKit is y-up with origin bottom-left.
/// Regression for jumps drawing downward and hit sparks drawing ~192 px left of the defender.
final class WorldToSceneTests: XCTestCase {
    func testGroundOriginMapsToStageCentreOnTheFloorLine() {
        let p = WorldToScene.point(simX: 0, simY: 0)
        XCTAssertEqual(p.x, SceneConstants.width / 2)
        XCTAssertEqual(p.y, WorldToScene.floorY)
    }

    func testAirborneFighterIsDrawnAboveTheFloor() {
        // 40 px up in the sim is y = -40 (y-down).
        let p = WorldToScene.point(simX: 0, simY: -40 * Fixed.scale)
        XCTAssertEqual(p.y, WorldToScene.floorY + 40)
    }

    func testHitSparkSitsOnTheDefenderNotTheStageEdge() throws {
        var snap = SimulationBootstrap.greyboxMatch()
        snap.events = [GameEvent(kind: .hit, attacker: .p1, defender: .p2)]
        let spark = try XCTUnwrap(CombatPresentation.sparks(from: snap).first)
        let defender = WorldToScene.point(
            simX: snap.fighters[1].position.x.raw,
            simY: snap.fighters[1].position.y.raw
        )
        XCTAssertEqual(spark.worldX, defender.x)
        XCTAssertGreaterThan(spark.worldY, defender.y, "spark sits at chest height above the feet")
    }

    func testProjectileCentreSitsOnItsHitboxAboveTheFloor() {
        let p = Projectile(
            id: 1, owner: .p1, position: Vec2(x: Fixed(pixels: 10), y: .zero),
            velocity: Vec2(x: Fixed(raw: 1024), y: .zero),
            hitbox: Hitbox(x: -16, y: -28, w: 32, h: 24), damage: 100, lifetimeTicks: 50
        )
        let c = WorldToScene.projectileCentre(p)
        XCTAssertEqual(c.x, SceneConstants.width / 2 + 10)
        XCTAssertEqual(c.y, WorldToScene.floorY + 16, "hitbox spans 4..28 px above the floor")
    }

    func testCameraScrollsUpOnlyWhenAJumpWouldLeaveTheScreen() {
        var snap = SimulationBootstrap.greyboxMatch()
        XCTAssertEqual(FightCameraMath.compute(snapshot: snap).scrollY, 0, "grounded: no vertical scroll")
        snap.fighters[0].position = Vec2(x: snap.fighters[0].position.x, y: Fixed(raw: -98 * Fixed.scale))
        let cam = FightCameraMath.compute(snapshot: snap)
        let top = WorldToScene.floorY + 98 + FightCamera.fighterHeadroom
        XCTAssertEqual(cam.scrollY, top - SceneConstants.height)
        XCTAssertGreaterThan(cam.scrollY, 0)
    }
}
