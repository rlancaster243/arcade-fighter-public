import XCTest
@testable import FightCore

/// Task T-CORE-AI: CPU difficulty profiles and deterministic AI inputs.
final class TCoreAITests: XCTestCase {
    func testT_CORE_AI_threeDifficultyTiersHaveDistinctProfiles() {
        let seed: UInt64 = 0x5151
        let easy = DifficultyProfile.seeded(difficulty: .easy, matchSeed: seed)
        let normal = DifficultyProfile.seeded(difficulty: .normal, matchSeed: seed)
        let hard = DifficultyProfile.seeded(difficulty: .hard, matchSeed: seed)
        XCTAssertLessThan(hard.reactionDelayTicks, easy.reactionDelayTicks)
        XCTAssertLessThan(easy.inputAccuracyPermille, hard.inputAccuracyPermille)
        XCTAssertLessThan(easy.blockRatePermille, hard.blockRatePermille)
        XCTAssertLessThan(easy.specialRatePermille, hard.specialRatePermille)
        XCTAssertLessThan(easy.superRatePermille, hard.superRatePermille)
        XCTAssertEqual(easy.difficulty, .easy)
        XCTAssertEqual(normal.difficulty, .normal)
        XCTAssertEqual(hard.difficulty, .hard)
    }

    func testT_CORE_AI_seededProfileIsStable() {
        let a = DifficultyProfile.seeded(difficulty: .normal, matchSeed: 4242)
        let b = DifficultyProfile.seeded(difficulty: .normal, matchSeed: 4242)
        XCTAssertEqual(a, b)
    }

    func testT_CORE_AI_inputsRepeatForSameTickAndSeed() {
        let profile = DifficultyProfile.seeded(difficulty: .hard, matchSeed: 99)
        let ai = CPUAIController(profile: profile)
        var snap = SimulationBootstrap.greyboxMatch(seed: 7)
        snap.tick = 240
        var rngA = snap.rng
        var rngB = snap.rng
        let f1 = ai.inputs(for: .p1, snapshot: snap, rng: &rngA)
        let f2 = ai.inputs(for: .p1, snapshot: snap, rng: &rngB)
        XCTAssertEqual(f1, f2)
    }

    func testT_CORE_AI_cpuControllersCoverAllDifficulties() {
        for d in Difficulty.allCases {
            let ai = CPUAIController(difficulty: d, matchSeed: 1)
            XCTAssertEqual(ai.profile.difficulty, d)
        }
    }
}