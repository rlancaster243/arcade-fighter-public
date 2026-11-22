import XCTest
import FightCore

/// Re-records `expected-hashes.json` tick sequences after an intended sim change.
/// Skipped unless `RECORD_EXPECTED_HASHES=<output path>` is set. Writes `{scenarioID: [hash]}`;
/// `scripts/record-expected-hashes.sh` merges it into the catalog and reruns the tests.
final class ExpectedHashesRecorder: XCTestCase {
    func testRecordExpectedHashes() throws {
        guard let out = ProcessInfo.processInfo.environment["RECORD_EXPECTED_HASHES"], !out.isEmpty else {
            throw XCTSkip("set RECORD_EXPECTED_HASHES=<path> to re-record goldens")
        }
        let catalog = try ExpectedHashesCatalog.load()
        var recorded: [String: [UInt64]] = [:]
        for scenario in catalog.scenarios {
            recorded[scenario.id] = try IntegrationMatchHarness.tickHashes(for: scenario)
        }
        let data = try JSONEncoder().encode(recorded)
        try data.write(to: URL(fileURLWithPath: out))
    }
}
