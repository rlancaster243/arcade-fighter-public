import XCTest
import FightCore

/// Proves the FIX-B golden scripts start the named moves. Hash equality stays in the catalog test.
final class KitScenarioFireTests: XCTestCase {
    func testKitScriptsFireTheListedMoves() throws {
        let catalog = try ExpectedHashesCatalog.load()
        try assertKestrel(try trace("script-kestrel-kit", catalog: catalog))
        try assertBruno(try trace("script-bruno-kit", catalog: catalog))
        try assertIlse(try trace("script-ilse-kit", catalog: catalog))
        try assertRook(try trace("script-rook-kit", catalog: catalog))
        XCTAssertNotNil(catalog.scenario(id: "cpu-kestrel-bruno"))
    }

    private func trace(_ id: String, catalog: ExpectedHashesCatalog) throws -> KitTrace {
        let scenario = try XCTUnwrap(catalog.scenario(id: id))
        let (p1, p2) = try IntegrationMatchHarness.loadFighters(scenario.fighters)
        let result = try IntegrationMatchHarness.runScriptedMatchTracing(
            seed: scenario.scriptSeed ?? 1,
            p1: p1,
            p2: p2,
            stageId: scenario.stageId,
            scenarioID: scenario.id
        )
        return result.trace
    }

    private func assertKestrel(_ trace: KitTrace) throws {
        for id in ["sp_rime_lk", "sp_rime_hk", "sp_crag_lp", "sp_crag_hp", "super_whiteout", "throw_lp_lk"] {
            XCTAssertTrue(trace.moveIDs.contains(id), detail(trace, missing: id))
        }
        XCTAssertTrue(threw(trace, "throw_lp_lk"), detail(trace, missing: "throw_lp_lk hit"))
    }

    private func assertBruno(_ trace: KitTrace) throws {
        for id in ["sp_bellows", "throw_lp_lk", "super_anvil", "sp_forge_quake"] {
            XCTAssertTrue(trace.moveIDs.contains(id), detail(trace, missing: id))
        }
        XCTAssertTrue(threw(trace, "sp_bellows"), detail(trace, missing: "bellows grab"))
        XCTAssertTrue(threw(trace, "super_anvil"), detail(trace, missing: "anvil grab"))
        XCTAssertTrue(threw(trace, "throw_lp_lk"), detail(trace, missing: "bruno throw"))
        XCTAssertTrue(trace.spawned.contains { !$0.hitsAirborne }, detail(trace, missing: "ground projectile"))
    }

    private func assertIlse(_ trace: KitTrace) throws {
        for id in ["sp_prayer_lp", "sp_prayer_hp", "sp_vesper_lk", "sp_vesper_hk", "super_rosary", "ilse_throw_lp_lk"] {
            XCTAssertTrue(trace.moveIDs.contains(id), detail(trace, missing: id))
        }
        XCTAssertTrue(threw(trace, "ilse_throw_lp_lk"), detail(trace, missing: "ilse throw"))
        let speeds = trace.spawned.map { abs($0.speedRaw) }
        XCTAssertTrue(speeds.contains(768), detail(trace, missing: "slow bead"))
        XCTAssertTrue(speeds.contains(1792), detail(trace, missing: "fast bead"))
        XCTAssertGreaterThanOrEqual(speeds.filter { $0 == 1280 }.count, 3, detail(trace, missing: "volley"))
    }

    private func assertRook(_ trace: KitTrace) throws {
        for id in ["sp_rocket_lp", "sp_rocket_hp", "sp_guard_protocol", "super_overclock", "rook_throw_lp_lk"] {
            XCTAssertTrue(trace.moveIDs.contains(id), detail(trace, missing: id))
        }
        XCTAssertTrue(trace.rocketArmor.contains(1), detail(trace, missing: "armor 1"))
        XCTAssertTrue(trace.rocketArmor.contains(0), detail(trace, missing: "armor absorbed"))
        XCTAssertTrue(
            trace.events.contains { $0.0 == .hit && $0.1 == "rook_norm_hp" },
            detail(trace, missing: "counter hit")
        )
        XCTAssertTrue(threw(trace, "rook_throw_lp_lk"), detail(trace, missing: "rook throw"))
    }

    private func threw(_ trace: KitTrace, _ moveID: String) -> Bool {
        trace.events.contains { $0.0 == .throwHit && $0.1 == moveID }
    }

    private func detail(_ trace: KitTrace, missing: String) -> String {
        let moves = trace.moveIDs.sorted().joined(separator: ",")
        let events = trace.events.map { "\($0.0.rawValue):\($0.1)" }.joined(separator: ",")
        let spawned = trace.spawned.map { "\(abs($0.speedRaw))/\($0.hitsAirborne)" }.joined(separator: ",")
        return "missing \(missing); moves=[\(moves)] events=[\(events)] spawned=[\(spawned)] armor=\(trace.rocketArmor)"
    }
}
