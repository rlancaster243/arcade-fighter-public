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

/// Regression: a fighter whose stun ended in mid-air went back to `.idle` and could jump again,
/// glide by holding forward, or hover by attacking; and throws grabbed jumpers at any height.
final class AirRecoveryTests: XCTestCase {
    func testStunEndingAboveTheFloorBecomesAirborneNotIdle() throws {
        let def = try FighterTestFixtures.greyboxDef()
        var sim = Simulation(
            motion: MotionParser(),
            fighterStep: FighterStepper(definitions: [def.id: def]),
            collision: CollisionResolver(context: CollisionMatchContext(fighterDefs: [def, def]))
        )
        var snap = SimulationBootstrap.greyboxMatch()
        snap.fighters[1].position.y = Fixed(raw: -80 * Fixed.scale)
        snap.fighters[1].kind = .hitstun
        snap.fighters[1].timer = 3
        var kindsAloft = Set<FighterStateKind>()
        var landed = false
        for _ in 0..<300 {
            // Holding up and forward would double-jump or glide if the fighter were idle in the air.
            sim.step(inputs: [InputFrame(), InputFrame(direction: .upLeft)], snapshot: &snap)
            let f = snap.fighters[1]
            if f.position.y.raw < FighterConstants.groundY { kindsAloft.insert(f.kind) } else { landed = true; break }
        }
        XCTAssertTrue(landed, "should come down")
        XCTAssertTrue(kindsAloft.isSubset(of: [.hitstun, .airborne]), "aloft kinds: \(kindsAloft)")
    }

    func testThrowsDoNotConnectWithADefenderOffTheFloor() {
        let toss = MoveDef(id: "throw_lp_lk", name: "Throw", inputKind: .throwMove, startup: 1, active: 1, recovery: 1)
        let attacker = FighterState(position: Vec2(x: .zero, y: Fixed(raw: FighterConstants.groundY)), facingRight: true, health: 1000)
        var defender = FighterState(position: Vec2(x: Fixed(raw: 20 * Fixed.scale), y: Fixed(raw: FighterConstants.groundY)), facingRight: false, health: 1000)
        XCTAssertTrue(ThrowLogic.canConnectThrow(attacker: attacker, defender: defender, move: toss))
        defender.position.y = Fixed(raw: FighterConstants.groundY - 90 * Fixed.scale)
        defender.kind = .airborne
        XCTAssertFalse(ThrowLogic.canConnectThrow(attacker: attacker, defender: defender, move: toss))
    }
}
