import XCTest
@testable import FightCore

/// T-CORE-TIMER
final class T_CORE_TIMERTests: XCTestCase {
    func testRoundTickLimitConstant() {
        XCTAssertEqual(MatchRules.roundTickLimit, 5940)
    }

    func testDisplaySecondsCeilRemaining() {
        var rules = MatchRules(roundTick: 0)
        XCTAssertEqual(rules.displaySeconds, 99)
        rules.roundTick = 1
        XCTAssertEqual(rules.displaySeconds, 99)
        rules.roundTick = 60
        XCTAssertEqual(rules.displaySeconds, 98)
        rules.roundTick = 5939
        XCTAssertEqual(rules.displaySeconds, 1)
        rules.roundTick = 5940
        XCTAssertEqual(rules.displaySeconds, 0)
    }

    func testHitstopPausesRoundTimer() {
        var director = MatchDirector()
        var snap = MatchTestSupport.snapshot(roundTick: 100)
        snap.rules.hitstopRemaining = 3
        director.applyRules(snapshot: &snap)
        XCTAssertEqual(snap.rules.roundTick, 100)
        XCTAssertEqual(snap.rules.hitstopRemaining, 2)
    }

    func testRoundTimerAdvancesWhenNotFrozen() {
        var director = MatchDirector()
        var snap = MatchTestSupport.snapshot(roundTick: 100)
        director.applyRules(snapshot: &snap)
        XCTAssertEqual(snap.rules.roundTick, 101)
    }

    func testTimeOverAtLimit() {
        var director = MatchDirector()
        var snap = MatchTestSupport.snapshot(p1Health: 700, p2Health: 500, roundTick: MatchRules.roundTickLimit - 1)
        director.applyRules(snapshot: &snap)
        XCTAssertEqual(snap.rules.roundTick, MatchRules.roundTickLimit)
        XCTAssertEqual(snap.rules.p1RoundsWon, 1)
    }

    func testGlobalTickAlwaysAdvances() {
        var director = MatchDirector()
        var snap = MatchTestSupport.snapshot()
        snap.tick = 50
        snap.rules.hitstopRemaining = 5
        director.applyRules(snapshot: &snap)
        XCTAssertEqual(snap.tick, 51)
    }
}