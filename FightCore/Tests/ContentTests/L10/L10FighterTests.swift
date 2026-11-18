import XCTest
@testable import FightCore

final class L10FighterTests: XCTestCase {
    func testIlseLoadsAndHasSpecials() throws {
        let def = try FighterLoader.loadFighter(from: L10ContentPaths.ilseDirectory())
        XCTAssertEqual(def.id, "ilse")
        XCTAssertEqual(def.displayName, "Sister Ilse")
        XCTAssertFalse(def.gamePlan.isEmpty)
        XCTAssertEqual(def.health, 950)
        XCTAssertTrue(def.moves.contains { $0.inputKind == .special })
        XCTAssertTrue(def.moves.contains { $0.inputKind == .superMove })
        XCTAssertTrue(def.moves.contains { $0.inputKind == .throwMove })
        let normals = def.moves.filter { $0.inputKind == .normal }
        XCTAssertGreaterThanOrEqual(normals.count, 4)
    }

    func testRookLoadsAndIsSlower() throws {
        let def = try FighterLoader.loadFighter(from: L10ContentPaths.rookDirectory())
        XCTAssertEqual(def.id, "rook")
        XCTAssertEqual(def.walkForward, 2 * Fixed.scale)
        XCTAssertGreaterThan(def.health, 1000)
        let names = Set(def.moves.map(\.id))
        XCTAssertTrue(names.contains("rook_throw_lp_lk"))
        XCTAssertTrue(names.contains("rook_sp_qcf"))
    }
}