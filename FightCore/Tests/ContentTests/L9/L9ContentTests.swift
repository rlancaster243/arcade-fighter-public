import XCTest
@testable import FightCore

final class L9ContentTests: XCTestCase {
    private func fighterDirectory(_ id: String) -> URL {
        ContentPaths.fighterDirectory(id)
    }

    private func stageDirectory() -> URL {
        ContentPaths.stageDirectory("stage1")
    }

    func testKestrelLoadsWithFullRosterStates() throws {
        let def = try FighterLoader.loadFighter(from: fighterDirectory("kestrel"))
        XCTAssertEqual(def.id, "kestrel")
        XCTAssertEqual(def.displayName, "Kestrel Vane")
        XCTAssertFalse(def.gamePlan.isEmpty)
        let states = Set(def.hurtboxes.map(\.state))
        XCTAssertEqual(states.count, FighterStateKind.allCases.count)
        XCTAssertEqual(def.moves.count, 7)
        XCTAssertTrue(def.moves.contains { $0.id == "super_blizzard" })
    }

    func testBrunoLoadsWithFullRosterStates() throws {
        let def = try FighterLoader.loadFighter(from: fighterDirectory("bruno"))
        XCTAssertEqual(def.id, "bruno")
        XCTAssertEqual(def.displayName, "Bruno Okafor")
        XCTAssertEqual(def.health, 1050)
        let states = Set(def.hurtboxes.map(\.state))
        XCTAssertEqual(states.count, FighterStateKind.allCases.count)
        XCTAssertTrue(def.moves.contains { $0.id == "super_forge_break" })
    }

    func testGlacierForgeQuarryStageBundle() throws {
        let dir = stageDirectory()
        let stageURL = dir.appendingPathComponent("stage.json")
        let data = try Data(contentsOf: stageURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["schemaVersion"] as? Int, 1)
        XCTAssertEqual(json?["id"] as? String, "stage1")
        XCTAssertEqual(json?["displayName"] as? String, "Glacier Forge Quarry")
        let bg = json?["background"] as? String ?? ""
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent(bg).path))
    }

    func testFighterSheetsAreIndexedSprites() throws {
        for id in ["kestrel", "bruno"] {
            let dir = fighterDirectory(id)
            let def = try FighterLoader.loadFighter(from: dir)
            let sheet = dir.appendingPathComponent(def.spriteSheetPath)
            XCTAssertTrue(FileManager.default.fileExists(atPath: sheet.path))
        }
    }
}