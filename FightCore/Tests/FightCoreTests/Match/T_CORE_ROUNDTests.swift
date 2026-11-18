import XCTest
@testable import FightCore

/// T-CORE-ROUND
final class T_CORE_ROUNDTests: XCTestCase {
    func testKO_awardsRoundToSurvivor() {
        var director = MatchDirector()
        var snap = MatchTestSupport.snapshot(p1Health: 0, p2Health: 400)
        director.applyRules(snapshot: &snap)
        XCTAssertEqual(snap.rules.p2RoundsWon, 1)
        XCTAssertEqual(snap.rules.p1RoundsWon, 0)
        XCTAssertFalse(snap.rules.matchOver)
        XCTAssertEqual(snap.fighters[1].kind, .win)
        XCTAssertEqual(snap.rules.roundNumber, 2)
        XCTAssertEqual(snap.fighters[0].health, 1000)
        XCTAssertEqual(snap.fighters[1].health, 1000)
    }

    func testDoubleKO_isDrawNoRoundAwarded() {
        var director = MatchDirector()
        var snap = MatchTestSupport.snapshot(p1Health: 0, p2Health: 0)
        director.applyRules(snapshot: &snap)
        XCTAssertEqual(snap.rules.p1RoundsWon, 0)
        XCTAssertEqual(snap.rules.p2RoundsWon, 0)
        XCTAssertFalse(snap.rules.matchOver)
    }

    func testFirstToTwoRoundsEndsMatch() {
        var director = MatchDirector()
        var snap = MatchTestSupport.snapshot(p1Health: 0, p2Rounds: 1)
        director.applyRules(snapshot: &snap)
        XCTAssertTrue(snap.rules.matchOver)
        XCTAssertEqual(snap.rules.winner, PlayerSlot.p2)
        XCTAssertTrue(snap.events.contains { $0.kind == .matchWin })
    }

    func testFiveRoundCapEndsMatchWhenStillTied() {
        var director = MatchDirector()
        var snap = MatchTestSupport.snapshot(
            p1Health: 500,
            p2Health: 500,
            roundTick: MatchRules.roundTickLimit - 1,
            roundNumber: 5,
            p1Rounds: 1,
            p2Rounds: 1
        )
        director.applyRules(snapshot: &snap)
        XCTAssertTrue(snap.rules.matchOver)
        XCTAssertNil(snap.rules.winner)
    }

    func testFiveRoundCapPicksLeader() {
        var director = MatchDirector()
        var snap = MatchTestSupport.snapshot(
            p1Health: 700,
            p2Health: 400,
            roundTick: MatchRules.roundTickLimit - 1,
            roundNumber: 5,
            p1Rounds: 1,
            p2Rounds: 1
        )
        director.applyRules(snapshot: &snap)
        XCTAssertTrue(snap.rules.matchOver)
        XCTAssertEqual(snap.rules.winner, PlayerSlot.p1)
    }

    func testTimeOverHigherHealthWinsRound() {
        var director = MatchDirector()
        var snap = MatchTestSupport.snapshot(p1Health: 600, p2Health: 400, roundTick: MatchRules.roundTickLimit - 1)
        director.applyRules(snapshot: &snap)
        XCTAssertEqual(snap.rules.p1RoundsWon, 1)
        XCTAssertTrue(snap.events.contains { $0.kind == .timeOver })
    }

    func testTimeOverDrawAwardsNoRound() {
        var director = MatchDirector()
        var snap = MatchTestSupport.snapshot(p1Health: 500, p2Health: 500, roundTick: MatchRules.roundTickLimit - 1)
        director.applyRules(snapshot: &snap)
        XCTAssertEqual(snap.rules.p1RoundsWon, 0)
        XCTAssertEqual(snap.rules.p2RoundsWon, 0)
        XCTAssertTrue(snap.events.contains { $0.kind == .timeOver })
    }

    func testRoundStartEventAfterRoundReset() {
        var director = MatchDirector()
        var snap = MatchTestSupport.snapshot(p1Health: 0)
        director.applyRules(snapshot: &snap)
        XCTAssertTrue(snap.events.contains { $0.kind == .roundStart })
    }
}