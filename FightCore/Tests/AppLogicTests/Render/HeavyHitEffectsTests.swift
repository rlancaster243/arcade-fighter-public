import XCTest
import FightCore
@testable import AppLogic

final class HitFlashTests: XCTestCase {
    func testFlashLastsThreeTicksAndFades() {
        XCTAssertEqual(HitFlashLife.ticks, 3)
        let a = HitFlashLife.blend(ageTicks: 0)!
        let b = HitFlashLife.blend(ageTicks: 1)!
        let c = HitFlashLife.blend(ageTicks: 2)!
        XCTAssertGreaterThan(a, b)
        XCTAssertGreaterThan(b, c)
        XCTAssertGreaterThan(c, 0)
        XCTAssertLessThanOrEqual(a, 1)
        XCTAssertNil(HitFlashLife.blend(ageTicks: 3))
        XCTAssertNil(HitFlashLife.blend(ageTicks: -1))
    }

    /// A 3-tick flash sampled at any of its frames must still read as a white pop, not a grey wash.
    func testEveryFlashFrameIsStrongAndFirstIsPureWhite() {
        XCTAssertEqual(HitFlashLife.blend(ageTicks: 0), 1.0)
        for age in 0..<HitFlashLife.ticks {
            XCTAssertGreaterThanOrEqual(HitFlashLife.blend(ageTicks: age)!, 0.7, "age \(age)")
        }
    }

    func testTrackerFlashesOnlyTheStruckSlot() {
        var tracker = HitFlashTracker()
        tracker.trigger(slot: 1, tick: 100)
        XCTAssertGreaterThan(tracker.blend(slot: 1, tick: 100), 0)
        XCTAssertGreaterThan(tracker.blend(slot: 1, tick: 102), 0)
        XCTAssertEqual(tracker.blend(slot: 1, tick: 103), 0)
        XCTAssertEqual(tracker.blend(slot: 0, tick: 100), 0)
    }

    func testTrackerIgnoresTickRewind() {
        var tracker = HitFlashTracker()
        tracker.trigger(slot: 0, tick: 500)
        XCTAssertEqual(tracker.blend(slot: 0, tick: 2), 0)
    }

    func testRetriggerRestartsTheFlash() {
        var tracker = HitFlashTracker()
        tracker.trigger(slot: 0, tick: 10)
        tracker.trigger(slot: 0, tick: 12)
        XCTAssertGreaterThan(tracker.blend(slot: 0, tick: 14), 0)
    }
}

final class HeavyHitPresentationTests: XCTestCase {
    private func snap(_ events: [GameEvent]) -> GameSnapshot {
        var s = SimulationBootstrap.greyboxMatch()
        s.events = events
        return s
    }

    func testHeavyHitIsFlaggedAndTargetsTheDefender() {
        let heavy = GameEvent(kind: .hit, tick: 5, attacker: .p1, defender: .p2,
                              damage: CombatPresentation.heavyDamageThreshold)
        let sparks = CombatPresentation.sparks(from: snap([heavy]))
        XCTAssertEqual(sparks.count, 1)
        XCTAssertTrue(sparks[0].heavy)
        XCTAssertEqual(sparks[0].defenderIndex, 1)
        XCTAssertGreaterThan(sparks[0].scale, SparkRequest(kind: .hit, worldX: 0, worldY: 0).scale)
    }

    func testLightHitAndBlockAreNotHeavy() {
        let light = GameEvent(kind: .hit, tick: 5, defender: .p2, damage: CombatPresentation.heavyDamageThreshold - 1)
        let blockedBig = GameEvent(kind: .block, tick: 6, defender: .p1, damage: 200)
        let sparks = CombatPresentation.sparks(from: snap([light, blockedBig]))
        XCTAssertEqual(sparks.map(\.heavy), [false, false])
        XCTAssertEqual(sparks[1].defenderIndex, 0)
    }

    func testBlockSparkIsSmallerThanHitSpark() {
        let hit = SparkRequest(kind: .hit, worldX: 0, worldY: 0)
        let block = SparkRequest(kind: .block, worldX: 0, worldY: 0)
        XCTAssertLessThan(block.scale, hit.scale)
    }

    func testStreakCountsStayInRangeAndHeavyHasMore() {
        let hit = SparkRequest(kind: .hit, worldX: 0, worldY: 0)
        let heavy = SparkRequest(kind: .hit, worldX: 0, worldY: 0, heavy: true)
        let block = SparkRequest(kind: .block, worldX: 0, worldY: 0)
        for r in [hit, heavy, block] {
            XCTAssertTrue((6...10).contains(r.streakCount), "\(r.streakCount)")
        }
        XCTAssertGreaterThan(heavy.streakCount, block.streakCount)
    }

    func testStreakAnglesAreDeterministicAndRadiate() {
        let a = SparkShape.streakAngles(count: 8, seed: 42)
        XCTAssertEqual(a, SparkShape.streakAngles(count: 8, seed: 42))
        XCTAssertNotEqual(a, SparkShape.streakAngles(count: 8, seed: 43))
        XCTAssertEqual(a.count, 8)
        XCTAssertTrue(a.allSatisfy { $0 >= 0 && $0 < 2 * Double.pi })
        let sorted = a.sorted()
        for (x, y) in zip(sorted, sorted.dropFirst()) { XCTAssertGreaterThan(y - x, 0.2) }
    }
}
