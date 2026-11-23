import XCTest
@testable import FightCore

/// Regressions from jumps really leaving the floor.
final class JumpOverAndSettleTests: XCTestCase {
    private func fullSim() throws -> Simulation {
        let def = try FighterTestFixtures.greyboxDef()
        return Simulation(
            motion: MotionParser(),
            fighterStep: FighterStepper(definitions: [def.id: def]),
            collision: CollisionResolver(context: CollisionMatchContext(fighterDefs: [def, def]))
        )
    }

    /// Pushboxes separated on horizontal overlap alone, so a fighter high above the opponent
    /// still shoved them along the ground.
    func testAFighterOverheadDoesNotPushTheOneOnTheGround() throws {
        var sim = try fullSim()
        var snap = SimulationBootstrap.greyboxMatch()
        let groundX = snap.fighters[1].position.x.raw
        snap.fighters[0].position = Vec2(x: Fixed(raw: groundX), y: Fixed(raw: -150 * Fixed.scale))
        snap.fighters[0].kind = .airborne
        sim.step(inputs: [InputFrame(), InputFrame()], snapshot: &snap)
        XCTAssertEqual(snap.fighters[1].position.x.raw, groundX, "grounded fighter should not be pushed from above")
    }

    func testFightersStandingInEachOtherAreStillPushedApart() throws {
        var sim = try fullSim()
        var snap = SimulationBootstrap.greyboxMatch()
        snap.fighters[0].position.x = snap.fighters[1].position.x
        sim.step(inputs: [InputFrame(), InputFrame()], snapshot: &snap)
        XCTAssertNotEqual(snap.fighters[0].position.x.raw, snap.fighters[1].position.x.raw)
    }

    /// The session stops the sim at match over; a fighter KO'd in the air must still come down.
    func testPostMatchSettleBringsAnAirborneFighterToTheFloor() {
        var snap = SimulationBootstrap.greyboxMatch()
        snap.fighters[1].position.y = Fixed(raw: -90 * Fixed.scale)
        snap.fighters[1].velocity.y = Fixed(raw: -3 * Fixed.scale)
        snap.fighters[1].kind = .ko
        let x = snap.fighters[1].position.x.raw
        XCTAssertTrue(PostMatchSettle.anyAloft(snap))
        var ticks: Int32 = 0
        while PostMatchSettle.step(snapshot: &snap, gravities: [256, 256]), ticks < PostMatchSettle.maxTicks { ticks += 1 }
        XCTAssertFalse(PostMatchSettle.anyAloft(snap))
        XCTAssertLessThan(ticks, PostMatchSettle.maxTicks)
        XCTAssertEqual(snap.fighters[1].position.y.raw, FighterConstants.groundY)
        XCTAssertEqual(snap.fighters[1].position.x.raw, x)
        XCTAssertEqual(snap.fighters[1].kind, .ko)
        XCTAssertEqual(snap.fighters[0].position.y.raw, FighterConstants.groundY)
    }
}
