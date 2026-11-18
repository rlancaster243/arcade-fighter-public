import XCTest
@testable import FightCore

/// T-CORE-RESP: cancel windows and queued move responsiveness.
final class TCoreResponsivenessTests: XCTestCase {
    func testT_CORE_RESP_recoveryCancelIntoSecondNormal() throws {
        let def = try FighterTestFixtures.greyboxDef()
        let lp = FighterTestFixtures.move("norm_lp", in: def)
        var stepper = FighterTestFixtures.stepper(with: def)
        var snap = FighterTestFixtures.baseSnapshot(def: def)

        snap.fighters[0].activeMoveID = "norm_lp"
        stepper.stepFighters(snapshot: &snap)

        let ticksToLateRecovery = lp.startup + lp.active + lp.recovery - 3
        for _ in 0..<ticksToLateRecovery {
            stepper.stepFighters(snapshot: &snap)
        }
        XCTAssertEqual(snap.fighters[0].kind, .attackRecovery)

        snap.fighters[0].activeMoveID = "norm_hp"
        stepper.stepFighters(snapshot: &snap)

        XCTAssertEqual(snap.fighters[0].activeMoveID, "norm_hp")
        XCTAssertEqual(snap.fighters[0].kind, .attackStartup)
        XCTAssertEqual(snap.fighters[0].stateTick, 0)
    }

    func testT_CORE_RESP_cancelRejectedOutsideWindow() throws {
        let def = try FighterTestFixtures.greyboxDef()
        let lp = FighterTestFixtures.move("norm_lp", in: def)
        var stepper = FighterTestFixtures.stepper(with: def)
        var snap = FighterTestFixtures.baseSnapshot(def: def)

        snap.fighters[0].activeMoveID = "norm_lp"
        stepper.stepFighters(snapshot: &snap)

        let ticksToEarlyRecovery = lp.startup + lp.active
        for _ in 0..<ticksToEarlyRecovery {
            stepper.stepFighters(snapshot: &snap)
        }
        XCTAssertEqual(snap.fighters[0].kind, .attackRecovery)

        snap.fighters[0].activeMoveID = "norm_hp"
        stepper.stepFighters(snapshot: &snap)

        XCTAssertEqual(snap.fighters[0].activeMoveID, "norm_lp")
        XCTAssertEqual(snap.fighters[0].kind, .attackRecovery)
    }
}