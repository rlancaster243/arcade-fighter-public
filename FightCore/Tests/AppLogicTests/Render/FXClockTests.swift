import XCTest
import FightCore
@testable import AppLogic

final class FXClockTests: XCTestCase {
    func testFollowsSimTicksWhileTheSimRuns() {
        var clock = FXClock()
        clock.advance(snapshotTick: 10, dt: 0)
        let start = clock.now
        clock.advance(snapshotTick: 11, dt: 1.0 / 120)
        clock.advance(snapshotTick: 11, dt: 1.0 / 120) // 120 Hz display: same tick twice
        clock.advance(snapshotTick: 13, dt: 1.0 / 120)
        XCTAssertEqual(clock.now - start, 3)
    }

    /// Regression: a match-winning heavy hit left the loser white and the spark lit for the whole
    /// result screen, because the sim tick stops once the match is over.
    func testKeepsCountingWhenTheSnapshotStopsAdvancing() {
        var clock = FXClock()
        var flash = HitFlashTracker()
        clock.advance(snapshotTick: 500, dt: 0)
        flash.trigger(slot: 1, tick: clock.now)
        XCTAssertGreaterThan(flash.blend(slot: 1, tick: clock.now), 0)
        for _ in 0..<30 { clock.advance(snapshotTick: 500, dt: 1.0 / 60) } // half a second, tick frozen
        XCTAssertEqual(flash.blend(slot: 1, tick: clock.now), 0)
        XCTAssertNil(SparkLife.state(ageTicks: clock.now))
    }

    func testNeverRunsBackwardsAcrossANewMatch() {
        var clock = FXClock()
        clock.advance(snapshotTick: 900, dt: 0)
        clock.advance(snapshotTick: 901, dt: 0.016)
        let before = clock.now
        clock.advance(snapshotTick: 0, dt: 0.016)
        XCTAssertGreaterThan(clock.now, before)
    }

    /// Regression: a rendered frame with no sim step was credited from wall time and then again
    /// from the next sim delta, so the clock ran ahead of the sim.
    func testAStalledFrameIsNotCountedTwice() {
        var clock = FXClock()
        clock.advance(snapshotTick: 100, dt: 0)
        let start = clock.now
        clock.advance(snapshotTick: 100, dt: 0.0168) // no sim step this frame
        clock.advance(snapshotTick: 102, dt: 0.0166) // two catch-up steps
        XCTAssertEqual(clock.now - start, 2)
    }

    /// Regression: Rook's jab (92 damage) counted as a heavy hit and strobed the flash.
    func testLightNormalsAreNeverHeavyHits() {
        let jab = GameEvent(kind: .hit, tick: 1, moveID: "rook_norm_lp", damage: 92)
        let fierce = GameEvent(kind: .hit, tick: 1, moveID: "rook_norm_hp", damage: 92)
        XCTAssertFalse(CombatPresentation.isHeavy(jab))
        XCTAssertTrue(CombatPresentation.isHeavy(fierce))
        XCTAssertFalse(CombatPresentation.isHeavy(GameEvent(kind: .hit, tick: 1, moveID: "norm_hp", damage: 84)))
    }

    /// Regression: a block that took chip damage showed no block spark.
    func testChipBlockStillShowsABlockSpark() {
        var snap = SimulationBootstrap.greyboxMatch()
        snap.events = [GameEvent(kind: .chip, tick: 1, attacker: .p1, defender: .p2, damage: 5)]
        XCTAssertEqual(CombatPresentation.sparks(from: snap).map(\.kind), [.block])
    }
}
