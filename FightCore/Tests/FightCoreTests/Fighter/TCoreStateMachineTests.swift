import XCTest
@testable import FightCore

/// T-CORE-SM: fighter state machine and frame-data phase transitions.
final class TCoreStateMachineTests: XCTestCase {
    func testT_CORE_SM_attackPhaseProgression() throws {
        let def = try FighterTestFixtures.greyboxDef()
        let lp = FighterTestFixtures.move("norm_lp", in: def)
        var stepper = FighterTestFixtures.stepper(with: def)
        var snap = FighterTestFixtures.baseSnapshot(def: def)

        snap.fighters[0].activeMoveID = "norm_lp"
        stepper.stepFighters(snapshot: &snap)
        XCTAssertEqual(snap.fighters[0].kind, .attackStartup)
        XCTAssertEqual(snap.fighters[0].activeMoveID, "norm_lp")

        for _ in 0..<lp.startup {
            stepper.stepFighters(snapshot: &snap)
        }
        XCTAssertEqual(snap.fighters[0].kind, .attackActive)

        for _ in 0..<lp.active {
            stepper.stepFighters(snapshot: &snap)
        }
        XCTAssertEqual(snap.fighters[0].kind, .attackRecovery)

        for _ in 0..<lp.recovery {
            stepper.stepFighters(snapshot: &snap)
        }
        XCTAssertEqual(snap.fighters[0].kind, .idle)
        XCTAssertEqual(snap.fighters[0].activeMoveID, "")
    }

    func testT_CORE_SM_jumpStartupAirborneLanding() throws {
        let def = try FighterTestFixtures.greyboxDef()
        var stepper = FighterTestFixtures.stepper(with: def)
        var snap = FighterTestFixtures.baseSnapshot(def: def)

        snap.fighters[0].activeMoveID = FighterConstants.builtinJumpCommand
        stepper.stepFighters(snapshot: &snap)
        XCTAssertEqual(snap.fighters[0].kind, .jumpStartup)

        for _ in 0..<FighterConstants.jumpStartupTicks {
            stepper.stepFighters(snapshot: &snap)
        }
        XCTAssertEqual(snap.fighters[0].kind, .airborne)

        for _ in 0..<80 {
            stepper.stepFighters(snapshot: &snap)
            if snap.fighters[0].kind == .idle { break }
        }
        XCTAssertEqual(snap.fighters[0].kind, .idle)
    }

    func testT_CORE_SM_hitstunExpiresToIdle() throws {
        let def = try FighterTestFixtures.greyboxDef()
        var stepper = FighterTestFixtures.stepper(with: def)
        var snap = FighterTestFixtures.baseSnapshot(def: def)

        snap.fighters[0].kind = .hitstun
        snap.fighters[0].timer = 5
        stepper.stepFighters(snapshot: &snap)
        XCTAssertEqual(snap.fighters[0].timer, 4)

        for _ in 0..<4 {
            stepper.stepFighters(snapshot: &snap)
        }
        XCTAssertEqual(snap.fighters[0].kind, .idle)
        XCTAssertEqual(snap.fighters[0].timer, 0)
    }

    func testT_CORE_SM_walkAppliesHorizontalVelocity() throws {
        let def = try FighterTestFixtures.greyboxDef()
        var stepper = FighterTestFixtures.stepper(with: def)
        var snap = FighterTestFixtures.baseSnapshot(def: def)

        snap.fighters[0].kind = .walkForward
        snap.fighters[0].facingRight = true
        let startX = snap.fighters[0].position.x.raw
        stepper.stepFighters(snapshot: &snap)
        XCTAssertGreaterThan(snap.fighters[0].position.x.raw, startX)
    }
}