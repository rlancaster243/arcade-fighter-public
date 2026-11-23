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

    /// Regression: a block that took chip damage showed no block spark.
    func testChipBlockStillShowsABlockSpark() {
        var snap = SimulationBootstrap.greyboxMatch()
        snap.events = [GameEvent(kind: .chip, tick: 1, attacker: .p1, defender: .p2, damage: 5)]
        XCTAssertEqual(CombatPresentation.sparks(from: snap).map(\.kind), [.block])
    }
}
