import XCTest
@testable import FightCore

/// T-CORE-METER
final class T_CORE_METERTests: XCTestCase {
    func testHitGrantsAttackerAndDefenderMeter() {
        var director = MatchDirector(moveMetadata: MatchTestSupport.greyboxMeta)
        var snap = MatchTestSupport.snapshot()
        snap.events = [
            GameEvent(kind: .hit, tick: 0, attacker: .p1, defender: .p2, moveID: "lp", damage: 80),
        ]
        director.applyRules(snapshot: &snap)
        XCTAssertEqual(snap.fighters[0].meter, 120)
        XCTAssertEqual(snap.fighters[1].meter, 20)
    }

    func testBlockGrantsHalfMeterToAttacker() {
        var director = MatchDirector(moveMetadata: MatchTestSupport.greyboxMeta)
        var snap = MatchTestSupport.snapshot()
        snap.events = [
            GameEvent(kind: .block, tick: 0, attacker: .p1, defender: .p2, moveID: "lp", damage: 0),
        ]
        director.applyRules(snapshot: &snap)
        XCTAssertEqual(snap.fighters[0].meter, 60)
        XCTAssertEqual(snap.fighters[1].meter, 0)
    }

    func testMeterCapsAt1000() {
        var director = MatchDirector(moveMetadata: MatchTestSupport.greyboxMeta)
        var snap = MatchTestSupport.snapshot()
        snap.fighters[0].meter = 950
        snap.events = [
            GameEvent(kind: .hit, tick: 0, attacker: .p1, defender: .p2, moveID: "lp", damage: 10),
        ]
        director.applyRules(snapshot: &snap)
        XCTAssertEqual(snap.fighters[0].meter, MatchRules.meterCap)
    }

    func testSuperStartupSpends1000Meter() {
        var director = MatchDirector(moveMetadata: MatchTestSupport.greyboxMeta)
        var snap = MatchTestSupport.snapshot()
        snap.fighters[0].meter = 1000
        snap.fighters[0].kind = .attackStartup
        snap.fighters[0].activeMoveID = "super_test"
        snap.fighters[0].stateTick = 0
        director.applyRules(snapshot: &snap)
        XCTAssertEqual(snap.fighters[0].meter, 0)
    }

    func testSuperHitstopFreezeMinimum() {
        var director = MatchDirector(moveMetadata: MatchTestSupport.greyboxMeta)
        var snap = MatchTestSupport.snapshot()
        snap.events = [
            GameEvent(kind: .hit, tick: 0, attacker: .p1, defender: .p2, moveID: "super_test", damage: 300),
        ]
        director.applyRules(snapshot: &snap)
        XCTAssertGreaterThanOrEqual(snap.rules.hitstopRemaining, HitstopRules.superHitstopMinimum)
    }

    func testHeavyHitstopFromMetadata() {
        var director = MatchDirector(moveMetadata: MatchTestSupport.greyboxMeta)
        var snap = MatchTestSupport.snapshot()
        snap.events = [
            GameEvent(kind: .hit, tick: 0, attacker: .p1, defender: .p2, moveID: "hp", damage: 120),
        ]
        director.applyRules(snapshot: &snap)
        XCTAssertEqual(snap.rules.hitstopRemaining, 9)
    }
}