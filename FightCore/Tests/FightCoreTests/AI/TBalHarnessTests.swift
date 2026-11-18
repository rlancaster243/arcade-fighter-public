import XCTest
@testable import FightCore

#if canImport(Foundation)
import Foundation
#endif

/// Task T-BAL-HARNESS: batch FightSim driver and JSON report contract.
final class TBalHarnessTests: XCTestCase {
    func testT_BAL_HARNESS_batchIsDeterministic() {
        let config = FightSimBatchConfig(
            batchSeed: 0xBAL1,
            matchCount: 4,
            ticksPerMatch: 180,
            p1Difficulty: .normal,
            p2Difficulty: .hard
        )
        let a = AIMatchDriver.runBatch(config)
        let b = AIMatchDriver.runBatch(config)
        XCTAssertEqual(a, b)
    }

    func testT_BAL_HARNESS_reportEncodesValidJSON() throws {
        let config = FightSimBatchConfig(
            batchSeed: 12,
            matchCount: 2,
            ticksPerMatch: 60,
            p1Difficulty: .easy,
            p2Difficulty: .easy
        )
        let report = AIMatchDriver.runBatch(config)
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(FightSimBatchReport.self, from: data)
        XCTAssertEqual(decoded, report)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.matches.count, 2)
        XCTAssertEqual(decoded.p1Wins + decoded.p2Wins + decoded.draws, decoded.config.matchCount)
    }

    func testT_BAL_HARNESS_singleMatchProducesHash() {
        let p1 = DifficultyProfile.seeded(difficulty: .normal, matchSeed: 3)
        let p2 = DifficultyProfile.seeded(difficulty: .normal, matchSeed: 4)
        let (_, result) = AIMatchDriver.runMatch(matchSeed: 3, p1: p1, p2: p2, tickLimit: 120)
        XCTAssertEqual(result.ticksSimulated, 120)
        XCTAssertNotEqual(result.finalStateHash, 0)
    }
}