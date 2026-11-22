import XCTest
@testable import FightCore

final class L9ContentTests: XCTestCase {
    private func fighterDirectory(_ id: String) -> URL {
        ContentPaths.fighterDirectory(id)
    }

    private func stageDirectory() -> URL {
        ContentPaths.stageDirectory("stage1")
    }

    func testKestrelKitMatchesFixB() throws {
        let (def, raw) = try RosterKitSpec.load("kestrel")
        RosterKitSpec.assertIdentity(
            def,
            displayName: "Kestrel Vane",
            archetype: "rushdown",
            health: 900,
            walkForward: 640,
            walkBack: 768
        )
        XCTAssertEqual(Set(def.hurtboxes.map(\.state)).count, FighterStateKind.allCases.count)
        XCTAssertEqual(def.moves.count, 10)
        RosterKitSpec.assertNormalsAndThrow(raw)
        RosterKitSpec.assertSpecialNames(raw, names: ["Rime Slide", "Crag Hook"])
        RosterKitSpec.assertSuper(raw, name: "Whiteout Line", button: "P")

        let rime = RosterKitSpec.rows(raw, name: "Rime Slide")
        XCTAssertEqual(Set(rime.map(\.motion)), ["236"])
        XCTAssertEqual(Set(rime.map(\.button)), ["LK", "HK"])
        let rimeLK = try XCTUnwrap(def.moves.first { $0.id == "sp_rime_lk" })
        let rimeHK = try XCTUnwrap(def.moves.first { $0.id == "sp_rime_hk" })
        XCTAssertEqual(rimeLK.name, "Rime Slide")
        XCTAssertEqual(rimeHK.name, "Rime Slide")
        XCTAssertEqual(rimeLK.guardLevel, .low)
        XCTAssertEqual(rimeHK.guardLevel, .low)
        XCTAssertGreaterThan(forwardTravel(rimeHK), forwardTravel(rimeLK))
        XCTAssertLessThan(rimeLK.frames.hurt[0].h, 50)

        let crag = RosterKitSpec.rows(raw, name: "Crag Hook")
        XCTAssertEqual(Set(crag.map(\.motion)), ["623"])
        XCTAssertEqual(Set(crag.map(\.button)), ["LP", "HP"])
        let cragLP = try XCTUnwrap(def.moves.first { $0.id == "sp_crag_lp" })
        let cragHP = try XCTUnwrap(def.moves.first { $0.id == "sp_crag_hp" })
        XCTAssertEqual(cragLP.guardLevel, .high)
        XCTAssertEqual(cragHP.guardLevel, .high)
        XCTAssertTrue(cragLP.invulnerableFrames.isEmpty)
        XCTAssertEqual(cragHP.invulnerableFrames, [0, 1])
        XCTAssertTrue(cragHP.velocities.contains { $0.y < 0 })

        let whiteout = try XCTUnwrap(def.moves.first { $0.id == "super_whiteout" })
        XCTAssertEqual(whiteout.inputKind, .superMove)
        XCTAssertGreaterThanOrEqual(whiteout.hits.count, 3)
        XCTAssertEqual(whiteout.hitstop, 10)
        RosterKitSpec.assertNotPlusOnBlock(def)
        assertAuthoredHitstop(def)
    }

    func testBrunoKitMatchesFixB() throws {
        let (def, raw) = try RosterKitSpec.load("bruno")
        RosterKitSpec.assertIdentity(
            def,
            displayName: "Bruno \"Anvil\" Okafor",
            archetype: "grappler",
            health: 1150,
            walkForward: 320,
            walkBack: 512
        )
        XCTAssertEqual(Set(def.hurtboxes.map(\.state)).count, FighterStateKind.allCases.count)
        XCTAssertEqual(def.moves.count, 8)
        RosterKitSpec.assertNormalsAndThrow(raw)
        RosterKitSpec.assertSpecialNames(raw, names: ["Forge Quake", "Bellows Lift"])
        RosterKitSpec.assertSuper(raw, name: "Anvil Drop", button: "P")
        XCTAssertFalse(raw.contains { $0.motion == "623" })

        let quakeRaw = RosterKitSpec.rows(raw, name: "Forge Quake")
        XCTAssertEqual(quakeRaw.map(\.motion), ["214"])
        XCTAssertEqual(quakeRaw.map(\.button), ["P"])
        let quake = try XCTUnwrap(def.moves.first { $0.id == "sp_forge_quake" })
        let bead = try XCTUnwrap(quake.projectile)
        XCTAssertFalse(bead.hitsAirborne)
        XCTAssertEqual(bead.maxOnScreen, 1)
        XCTAssertEqual(bead.spawnCount, 1)

        let liftRaw = RosterKitSpec.rows(raw, name: "Bellows Lift")
        XCTAssertEqual(liftRaw.map(\.motion), ["236"])
        XCTAssertEqual(liftRaw.map(\.button), ["K"])
        let lift = try XCTUnwrap(def.moves.first { $0.id == "sp_bellows" })
        XCTAssertEqual(lift.guardLevel, .throwAttack)
        XCTAssertTrue(lift.unblockable)
        XCTAssertTrue(lift.whiffsVsAirborne)
        XCTAssertGreaterThanOrEqual(lift.recovery, 18)

        let anvil = try XCTUnwrap(def.moves.first { $0.id == "super_anvil" })
        XCTAssertEqual(anvil.inputKind, .superMove)
        XCTAssertEqual(anvil.guardLevel, .throwAttack)
        XCTAssertTrue(anvil.unblockable)
        XCTAssertTrue(anvil.whiffsVsAirborne)
        XCTAssertEqual(anvil.hitstop, 10)
        RosterKitSpec.assertNotPlusOnBlock(def)
        assertAuthoredHitstop(def)
    }

    func testGlacierForgeQuarryStageBundle() throws {
        let dir = stageDirectory()
        let stageURL = dir.appendingPathComponent("stage.json")
        let data = try Data(contentsOf: stageURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["schemaVersion"] as? Int, 1)
        XCTAssertEqual(json?["id"] as? String, "stage1")
        XCTAssertEqual(json?["displayName"] as? String, "Glacier Forge Quarry")
        let layers = json?["layers"] as? [[String: Any]] ?? []
        XCTAssertFalse(layers.isEmpty)
        for layer in layers {
            let image = try XCTUnwrap(layer["image"] as? String)
            XCTAssertFalse(image.isEmpty)
            XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent(image).path), image)
        }
    }

    func testFighterSheetsAreIndexedSprites() throws {
        for id in ["kestrel", "bruno"] {
            let dir = fighterDirectory(id)
            let def = try FighterLoader.loadFighter(from: dir)
            let sheet = dir.appendingPathComponent(def.spriteSheetPath)
            XCTAssertTrue(FileManager.default.fileExists(atPath: sheet.path))
        }
    }

    private func forwardTravel(_ move: MoveDef) -> Int32 {
        move.velocities.reduce(Int32(0)) { $0 + max(0, $1.x) }
    }

    private func assertAuthoredHitstop(_ def: FighterDef, file: StaticString = #filePath, line: UInt = #line) {
        for move in def.moves {
            switch move.inputKind {
            case .special:
                XCTAssertTrue((8 ... 10).contains(move.hitstop), move.id, file: file, line: line)
            case .superMove:
                XCTAssertEqual(move.hitstop, 10, move.id, file: file, line: line)
                XCTAssertTrue(move.hits.allSatisfy { $0.hitstop == 10 }, move.id, file: file, line: line)
            case .normal, .throwMove:
                break
            }
        }
    }
}
