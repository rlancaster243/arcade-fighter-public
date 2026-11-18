import Foundation
import XCTest
@testable import FightCore

struct RawMove {
    var id: String
    var name: String
    var motion: String?
    var button: String?
    var stance: String?
}

enum RosterKitSpec {
    static func load(_ id: String, fromFile file: String = #filePath) throws -> (FighterDef, [RawMove]) {
        let directory = ContentPaths.fighterDirectory(id, fromFile: file)
        let def = try FighterLoader.loadFighter(from: directory)
        let data = try Data(contentsOf: directory.appendingPathComponent("fighter.json"))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let moves = json?["moves"] as? [[String: Any]] ?? []
        let raw: [RawMove] = moves.map { move in
            let input = move["input"] as? [String: Any] ?? [:]
            return RawMove(
                id: move["id"] as? String ?? "",
                name: move["name"] as? String ?? "",
                motion: input["motion"] as? String,
                button: input["button"] as? String,
                stance: input["stance"] as? String
            )
        }
        return (def, raw)
    }

    static func assertIdentity(
        _ def: FighterDef,
        displayName: String,
        archetype: String,
        health: Int32,
        walkForward: Int32,
        walkBack: Int32,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(def.displayName, displayName, file: file, line: line)
        XCTAssertEqual(def.archetype, archetype, file: file, line: line)
        XCTAssertEqual(def.health, health, file: file, line: line)
        XCTAssertEqual(def.walkForward, walkForward, file: file, line: line)
        XCTAssertEqual(def.walkBack, walkBack, file: file, line: line)
        XCTAssertFalse(def.gamePlan.isEmpty, file: file, line: line)
    }

    static func assertNormalsAndThrow(_ raw: [RawMove], file: StaticString = #filePath, line: UInt = #line) {
        let normals = raw.filter { $0.motion == nil && $0.stance == "stand" }
        XCTAssertEqual(Set(normals.map(\.button)), ["LP", "HP", "LK", "HK"], file: file, line: line)
        let throwMoves = raw.filter { $0.stance == "throw" }
        XCTAssertEqual(throwMoves.count, 1, file: file, line: line)
        XCTAssertEqual(throwMoves.first?.button, "LP+LK", file: file, line: line)
        XCTAssertNil(throwMoves.first?.motion, file: file, line: line)
    }

    static func assertSpecialNames(
        _ raw: [RawMove],
        names: Set<String>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let specials = raw.filter { $0.motion != nil && $0.motion != "236236" }
        XCTAssertEqual(Set(specials.map(\.name)), names, file: file, line: line)
    }

    static func assertSuper(
        _ raw: [RawMove],
        name: String,
        button: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let supers = raw.filter { $0.motion == "236236" }
        XCTAssertEqual(Set(supers.map(\.name)), [name], file: file, line: line)
        XCTAssertEqual(supers.count, 1, file: file, line: line)
        XCTAssertEqual(supers.first?.button, button, file: file, line: line)
    }

    static func rows(_ raw: [RawMove], name: String) -> [RawMove] {
        raw.filter { $0.name == name }
    }

    /// On-block advantage when the listed hit (or the first active frame) connects.
    static func blockAdvantage(_ move: MoveDef) -> Int32 {
        if move.hits.isEmpty {
            return move.blockstun - ((move.active - 1) + move.recovery)
        }
        guard let last = move.hits.max(by: { $0.activeFrame < $1.activeFrame }) else { return 0 }
        let remaining = (move.active - 1 - last.activeFrame) + move.recovery
        return last.blockstun - remaining
    }

    static func assertNotPlusOnBlock(_ def: FighterDef, file: StaticString = #filePath, line: UInt = #line) {
        for move in def.moves where move.guardLevel != .throwAttack && move.active > 0 {
            XCTAssertLessThanOrEqual(
                blockAdvantage(move),
                4,
                "\(move.id) block advantage \(blockAdvantage(move))",
                file: file,
                line: line
            )
        }
    }
}
