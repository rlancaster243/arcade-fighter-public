import XCTest
import FightCore

final class ShippedContentIntegrationTests: XCTestCase {
    private var catalog: ExpectedHashesCatalog!

    override func setUpWithError() throws {
        catalog = try ExpectedHashesCatalog.load()
        XCTAssertEqual(catalog.schemaVersion, 2)
        try catalog.validateUniqueScenarioIDs()
    }

    func testCatalogFightersCoveredByScenarios() {
        let covered = Set(catalog.scenarios.flatMap(\.fighters))
        let expected = Set(catalog.catalogFighters)
        XCTAssertEqual(covered, expected, "each catalog fighter must appear in at least one scenario")
    }

    func testShippedStagesLoadIntoMatchBounds() throws {
        for stageId in IntegrationMatchHarness.shippedStageIDs {
            let bounds = try IntegrationMatchHarness.playBounds(stageId: stageId)
            XCTAssertNotEqual(bounds.playLeftPx, 0)
            XCTAssertGreaterThan(bounds.playRightPx, bounds.playLeftPx)

            let greybox = try IntegrationMatchHarness.loadFighter("greybox")
            let defaultSim = try IntegrationMatchHarness.simulation(p1: greybox, p2: greybox, stageId: stageId)
            guard let resolver = defaultSim.collision as? CollisionResolver else {
                XCTFail("expected CollisionResolver")
                return
            }
            XCTAssertNotEqual(
                resolver.context.playLeftPx,
                StageBounds.playLeftPx,
                "\(stageId) must change play bounds vs StageBounds default"
            )
        }
    }

    func testExpectedHashScenarios() throws {
        for scenario in catalog.scenarios {
            let hashes = try IntegrationMatchHarness.tickHashes(for: scenario)
            XCTAssertEqual(
                hashes.count,
                scenario.tickHashes.count,
                "\(scenario.id): golden tickHashes must match actual simulated length"
            )
            if scenario.kind == .cpu, let tickLimit = scenario.tickLimit {
                XCTAssertLessThanOrEqual(
                    hashes.count,
                    Int(tickLimit) + 1,
                    "\(scenario.id): cpu hashes must not assume full tickLimit when match ends early"
                )
            }
            XCTAssertEqual(
                hashes,
                scenario.tickHashes,
                hashDiag(actual: hashes, expected: scenario.tickHashes, scenario: scenario.id)
            )
        }
    }
}

private func hashDiag(actual: [UInt64], expected: [UInt64], scenario: String) -> String {
    let sampleActual = actual.prefix(3).map { "0x\(String($0, radix: 16))" }.joined(separator: ", ")
    let sampleExpected = expected.prefix(3).map { "0x\(String($0, radix: 16))" }.joined(separator: ", ")
    return "\(scenario): count actual=\(actual.count) expected=\(expected.count); head actual=[\(sampleActual)] expected=[\(sampleExpected)]"
}