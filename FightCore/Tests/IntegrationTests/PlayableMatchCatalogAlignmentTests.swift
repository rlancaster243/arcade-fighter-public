import AppLogic
import XCTest
import FightCore

final class PlayableMatchCatalogAlignmentTests: XCTestCase {
    private var catalog: ExpectedHashesCatalog!

    override func setUpWithError() throws {
        catalog = try ExpectedHashesCatalog.load()
    }

    func testPlayableStackMatchesScriptKestrelBrunoCatalog() throws {
        guard let scenario = catalog.scenario(id: "script-kestrel-bruno") else {
            return XCTFail("missing script-kestrel-bruno scenario")
        }
        XCTAssertEqual(scenario.kind, .script)
        let (p1, p2) = try IntegrationMatchHarness.loadFighters(["kestrel", "bruno"])
        guard let seed = scenario.scriptSeed else {
            return XCTFail("script seed required")
        }
        let hashes = try IntegrationMatchHarness.runScriptedKestrelBruno(seed: seed, stageId: scenario.stageId)
        XCTAssertEqual(hashes, scenario.tickHashes, "playable stack must match catalog goldens")
    }

    func testMatchBootstrapUsesFighterHealthFromContent() throws {
        let setup = MatchSetup(
            mode: .versus,
            p1: FighterPick(rosterIndex: 0, id: "kestrel"),
            p2: FighterPick(rosterIndex: 1, id: "bruno"),
            stageIndex: 0
        )
        let snap = MatchBootstrap.snapshot(for: setup, seed: 0xBEEF)
        XCTAssertEqual(snap.fighters[0].health, 950)
        XCTAssertEqual(snap.fighters[1].health, 1050)
    }
}