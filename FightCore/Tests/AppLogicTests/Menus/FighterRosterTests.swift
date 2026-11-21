import XCTest
@testable import AppLogic
import FightCore

final class FighterRosterTests: XCTestCase {
    /// Regression: the roster stayed `["greybox"]` after the shipped fighters landed, so none of
    /// them could be picked in the app. Every shipped bundle must be selectable or explicitly excluded.
    func testEveryShippedFighterBundleIsSelectableOrExplicitlyExcluded() throws {
        let fightersDir = ContentPaths.repoRoot(fromFile: #filePath)
            .appendingPathComponent("Content/Fighters", isDirectory: true)
        let shipped = Set(try FileManager.default.contentsOfDirectory(atPath: fightersDir.path)
            .filter { !$0.hasPrefix(".") })
        XCTAssertFalse(shipped.isEmpty)

        let missing = shipped
            .subtracting(FighterRoster.entries)
            .subtracting(FighterRoster.nonSelectableContentIDs)
        XCTAssertEqual(missing, [], "shipped fighters missing from FighterRoster.entries")

        let unknown = Set(FighterRoster.entries).subtracting(shipped)
        XCTAssertEqual(unknown, [], "roster ids without a Content/Fighters bundle")
        XCTAssertEqual(Set(FighterRoster.entries).count, FighterRoster.count, "duplicate roster ids")
    }

    func testEveryRosterFighterLoadsAndBuildsAMatch() throws {
        for id in FighterRoster.entries {
            let def = try FighterLoader.loadFighter(
                from: ContentPaths.fighterDirectory(id, fromFile: #filePath)
            )
            XCTAssertEqual(def.id, id)
            XCTAssertNoThrow(
                try MatchSimulationFactory.make(
                    p1PickID: id,
                    p1: def,
                    p2PickID: id,
                    p2: def,
                    stageId: "stage1",
                    fromFile: #filePath
                ),
                "\(id) mirror match failed to build"
            )
        }
    }

    func testCharacterSelectCyclesThroughTheWholeRoster() {
        var state = MenuShellState(screen: .characterSelect(.versus(selecting: .p1, p1: nil, p2: nil)))
        var seen: [String] = []
        for _ in 0..<FighterRoster.count {
            seen.append(FighterRoster.id(at: state.characterCursor))
            MenuReducer.reduce(state: &state, command: .right)
        }
        XCTAssertEqual(seen, FighterRoster.entries)
        XCTAssertEqual(state.characterCursor, 0, "right from the last fighter wraps to the first")
    }
}
