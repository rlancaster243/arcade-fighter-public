import XCTest
@testable import FightCore

/// Regression: the stage-bounds clamp in `CollisionResolver.resolveMovement` pinned every
/// fighter's y to the floor each tick, so jumps entered `.airborne` but never left the ground.
/// The state-machine jump test steps fighters only, so it could not see this; this one runs
/// the full `Simulation.step` (motion -> fighters -> collision -> rules).
final class JumpThroughResolverTests: XCTestCase {
    private func fullSim() throws -> (Simulation, FighterDef) {
        let def = try FighterTestFixtures.greyboxDef()
        let sim = Simulation(
            motion: MotionParser(),
            fighterStep: FighterStepper(definitions: [def.id: def]),
            collision: CollisionResolver(context: CollisionMatchContext(fighterDefs: [def, def]))
        )
        return (sim, def)
    }

    func testJumpLeavesTheFloorAndLandsThroughFullStep() throws {
        var (sim, _) = try fullSim()
        var snap = SimulationBootstrap.greyboxMatch()

        var minY = Int32.max
        var sawAirborne = false
        var landed = false
        for tick in 0..<180 {
            let p1 = tick < 3 ? InputFrame(direction: .up) : InputFrame()
            sim.step(inputs: [p1, InputFrame()], snapshot: &snap)
            let f = snap.fighters[0]
            minY = min(minY, f.position.y.raw)
            if f.kind == .airborne { sawAirborne = true }
            if sawAirborne, f.kind == .landing || f.kind == .idle { landed = true; break }
        }

        XCTAssertTrue(sawAirborne, "up input should reach .airborne")
        // Sim is y-down: height above the floor is negative y.
        XCTAssertLessThan(minY, -20 * Fixed.scale, "jump apex should be well above the floor")
        XCTAssertTrue(landed, "fighter should come back down and land")
        XCTAssertEqual(snap.fighters[0].position.y.raw, FighterConstants.groundY)
    }

    func testGroundedFightersStayOnTheFloor() throws {
        var (sim, _) = try fullSim()
        var snap = SimulationBootstrap.greyboxMatch()
        for _ in 0..<60 {
            sim.step(inputs: [InputFrame(direction: .right), InputFrame(direction: .left)], snapshot: &snap)
        }
        XCTAssertEqual(snap.fighters[0].position.y.raw, FighterConstants.groundY)
        XCTAssertEqual(snap.fighters[1].position.y.raw, FighterConstants.groundY)
    }
}
