import XCTest
@testable import FightCore

/// Regression: once the stage clamp stopped pinning y to the floor, a fighter knocked into a
/// "grounded" state (hitstun, blockstun, being thrown) while in the air got no gravity and hung
/// or drifted upward forever. Runs the full `Simulation.step`.
final class AirHitGravityTests: XCTestCase {
    private func fullSim() throws -> Simulation {
        let def = try FighterTestFixtures.greyboxDef()
        return Simulation(
            motion: MotionParser(),
            fighterStep: FighterStepper(definitions: [def.id: def]),
            collision: CollisionResolver(context: CollisionMatchContext(fighterDefs: [def, def]))
        )
    }

    private func assertComesDown(_ kind: FighterStateKind, risingAt vy: Int32, file: StaticString = #filePath, line: UInt = #line) throws {
        var sim = try fullSim()
        var snap = SimulationBootstrap.greyboxMatch()
        snap.fighters[1].position.y = Fixed(raw: -40 * Fixed.scale)
        snap.fighters[1].velocity.y = Fixed(raw: vy)
        snap.fighters[1].kind = kind
        snap.fighters[1].timer = 20
        var minY = Int32.max
        for _ in 0..<300 {
            sim.step(inputs: [InputFrame(), InputFrame()], snapshot: &snap)
            minY = min(minY, snap.fighters[1].position.y.raw)
        }
        XCTAssertEqual(snap.fighters[1].position.y.raw, FighterConstants.groundY, "\(kind) in the air should land", file: file, line: line)
        XCTAssertGreaterThan(minY, -200 * Fixed.scale, "\(kind) should not keep rising", file: file, line: line)
    }

    func testHitstunInTheAirFallsToTheFloor() throws {
        try assertComesDown(.hitstun, risingAt: -4 * Fixed.scale)
    }

    func testBlockstunInTheAirFallsToTheFloor() throws {
        try assertComesDown(.blockstunStand, risingAt: -4 * Fixed.scale)
    }

    func testIdleInTheAirFallsToTheFloor() throws {
        try assertComesDown(.idle, risingAt: 0)
    }
}
