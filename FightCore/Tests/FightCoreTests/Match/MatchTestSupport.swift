import XCTest
@testable import FightCore

enum MatchTestSupport {
    static let greyboxMeta: [String: MatchMoveMetadata] = [
        "lp": MatchMoveMetadata(meterGain: 120, hitstop: 6, isSuper: false),
        "hp": MatchMoveMetadata(meterGain: 120, hitstop: 9, isSuper: false),
        "super_test": MatchMoveMetadata(meterGain: 0, hitstop: 10, isSuper: true),
    ]

    static func snapshot(
        p1Health: Int32 = 1000,
        p2Health: Int32 = 1000,
        p1StartHealth: Int32 = 1000,
        p2StartHealth: Int32 = 1000,
        roundTick: Int32 = 0,
        roundNumber: Int32 = 1,
        p1Rounds: Int32 = 0,
        p2Rounds: Int32 = 0
    ) -> GameSnapshot {
        var snap = SimulationBootstrap.greyboxMatch()
        snap.fighterStartHealth = [p1StartHealth, p2StartHealth]
        snap.fighters[0].health = p1Health
        snap.fighters[1].health = p2Health
        snap.rules.roundTick = roundTick
        snap.rules.roundNumber = roundNumber
        snap.rules.p1RoundsWon = p1Rounds
        snap.rules.p2RoundsWon = p2Rounds
        return snap
    }

    static func stepRules(_ director: inout MatchDirector, _ snap: inout GameSnapshot) {
        director.applyRules(snapshot: &snap)
    }
}