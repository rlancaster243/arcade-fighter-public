import AppLogic
import XCTest
import FightCore

/// Ensures integration goldens match the playable `MatchSimulationFactory` + `RosterMatchDirector` stack.
final class PlayableMatchCatalogAlignmentTests: XCTestCase {
    private var catalog: ExpectedHashesCatalog!

    override func setUpWithError() throws {
        catalog = try ExpectedHashesCatalog.load()
    }

  /// `expected-hashes.json` tick sequences are recorded via `IntegrationMatchHarness`, which builds
  /// simulations through `MatchSimulationFactory` (stage play bounds + `RosterMatchDirector`). Re-record
  /// that JSON when this factory changes sim output; this test must fail on any drift.
    func testAllCatalogScenariosMatchPlayableFactoryGoldens() throws {
        for scenario in catalog.scenarios {
            let actual = try IntegrationMatchHarness.tickHashes(for: scenario)
            guard actual == scenario.tickHashes else {
                XCTFail(
                    catalogHashFailure(
                        scenarioID: scenario.id,
                        actual: actual,
                        expected: scenario.tickHashes
                    )
                )
                continue
            }
        }
    }

    func testMatchBootstrapUsesFighterHealthFromContent() throws {
        let setup = MatchSetup(
            mode: .versus,
            p1: FighterPick(rosterIndex: 0, id: "kestrel"),
            p2: FighterPick(rosterIndex: 1, id: "bruno"),
            stageIndex: 0
        )
        let snap = MatchBootstrap.snapshot(for: setup, seed: 0xBEEF)
        XCTAssertEqual(snap.fighters[0].health, 900)
        XCTAssertEqual(snap.fighters[1].health, 1150)
        XCTAssertEqual(snap.fighterStartHealth, [900, 1150])
    }

    func testRoundTwoRespawnUsesFighterStartHealthFromContent() {
        var snap = MatchSimulationFactory.matchSnapshot(
            seed: 1,
            p1: FighterDef(id: "kestrel", displayName: "K", gamePlan: "t", health: 900),
            p2: FighterDef(id: "bruno", displayName: "B", gamePlan: "t", health: 1150),
            fighterIDs: ["kestrel", "bruno"]
        )
        snap.fighters[0].health = 0
        var director = MatchDirector()
        director.applyRules(snapshot: &snap)
        XCTAssertEqual(snap.rules.roundNumber, 2)
        XCTAssertEqual(snap.fighters[0].health, 900)
        XCTAssertEqual(snap.fighters[1].health, 1150)
    }

    func testHUDHealthCapFromFighterStartHealth() throws {
        let setup = MatchSetup(
            mode: .versus,
            p1: FighterPick(rosterIndex: 0, id: "kestrel"),
            p2: FighterPick(rosterIndex: 1, id: "bruno"),
            stageIndex: 0
        )
        let snap = MatchBootstrap.snapshot(for: setup)
        let hud = HUDLayout.model(from: snap)
        XCTAssertEqual(hud.p1HealthCap, 900)
        XCTAssertEqual(hud.p2HealthCap, 1150)
    }
}

private func catalogHashFailure(
    scenarioID: String,
    actual: [UInt64],
    expected: [UInt64]
) -> String {
    if actual.count != expected.count {
        return "\(scenarioID): hash count actual=\(actual.count) expected=\(expected.count)"
    }
    for index in actual.indices where actual[index] != expected[index] {
        let a = actual[index]
        let e = expected[index]
        return """
        \(scenarioID): hash mismatch at index \(index) \
        actual=0x\(String(a, radix: 16)) expected=0x\(String(e, radix: 16)); \
        re-record FightCore/Tests/FightCoreTests/Contracts/expected-hashes.json if the factory change is intended
        """
    }
    return "\(scenarioID): hash mismatch (unknown)"
}