import XCTest
@testable import FightCore

final class DataValidationTests: XCTestCase {
    func testGreyboxLoads() throws {
        let dir = ContentPaths.greyboxDirectory()
        let def = try FighterLoader.loadFighter(from: dir)
        XCTAssertEqual(def.schemaVersion, 1)
        XCTAssertEqual(def.id, "greybox")
        XCTAssertEqual(def.moves.count, 7)
        let states = Set(def.hurtboxes.map(\.state))
        XCTAssertEqual(states.count, FighterStateKind.allCases.count)
    }

    func testWrongSchemaVersion() throws {
        let url = badCaseDirectory("bad_schema_version")
        XCTAssertThrowsError(try loadFixture(at: url)) { error in
            XCTAssertEqual(error as? FighterLoadError, .wrongSchemaVersion(2))
        }
    }

    func testDuplicateMoveID() throws {
        let url = badCaseDirectory("bad_duplicate_move")
        XCTAssertThrowsError(try loadFixture(at: url)) { error in
            XCTAssertEqual(error as? FighterLoadError, .duplicateMoveID("norm_lp"))
        }
    }

    func testNegativeFrameCount() throws {
        let url = badCaseDirectory("bad_negative_frames")
        XCTAssertThrowsError(try loadFixture(at: url)) { error in
            if case .negativeFrameCount(let id)? = error as? FighterLoadError {
                XCTAssertEqual(id, "norm_lp")
            } else {
                XCTFail("expected negativeFrameCount")
            }
        }
    }

    func testFrameBoxCountMismatch() throws {
        let url = badCaseDirectory("bad_box_mismatch")
        XCTAssertThrowsError(try loadFixture(at: url)) { error in
            if case .frameBoxCountMismatch(let id)? = error as? FighterLoadError {
                XCTAssertTrue(id.contains("norm_lp"))
            } else {
                XCTFail("expected frameBoxCountMismatch")
            }
        }
    }

    func testMissingSpriteName() throws {
        let url = badCaseDirectory("bad_missing_sprite")
        XCTAssertThrowsError(try loadFixture(at: url)) { error in
            XCTAssertEqual(error as? FighterLoadError, .missingSpriteName("missing_frame"))
        }
    }

    func testUnblockableNonThrow() throws {
        let url = badCaseDirectory("bad_unblockable")
        XCTAssertThrowsError(try loadFixture(at: url)) { error in
            XCTAssertEqual(error as? FighterLoadError, .unblockableNonThrow("cheat"))
        }
    }

    func testEmptyGamePlan() throws {
        let url = badCaseDirectory("bad_empty_gameplan")
        XCTAssertThrowsError(try loadFixture(at: url)) { error in
            XCTAssertEqual(error as? FighterLoadError, .emptyGamePlan)
        }
    }

    private func badCaseDirectory(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/bad_fighters/\(name)", isDirectory: true)
    }

    private func loadFixture(at dir: URL) throws -> FighterDef {
        try FighterLoader.loadFighter(from: dir)
    }
}