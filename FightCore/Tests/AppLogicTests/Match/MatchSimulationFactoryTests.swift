import AppLogic
import XCTest
import FightCore

final class MatchSimulationFactoryTests: XCTestCase {
    /// Regression: a pick whose bundle failed to load falls back to greybox. The factory must
    /// read greybox's commands, not the broken pick's bundle, and key them by the pick id.
    func testGreyboxFallbackBuildsAndKeysCommandsByRosterPick() throws {
        let greybox = try FighterLoader.loadFighter(from: ContentPaths.greyboxDirectory(fromFile: #filePath))
        XCTAssertEqual(greybox.id, "greybox")
        let bruno = try FighterLoader.loadFighter(
            from: ContentPaths.fighterDirectory("bruno", fromFile: #filePath)
        )

        let built = try MatchSimulationFactory.make(
            p1PickID: "missing_pick",
            p1: greybox,
            p2PickID: "bruno",
            p2: bruno,
            stageId: "stage1",
            fromFile: #filePath
        )

        let parser = try XCTUnwrap(built.simulation.motion as? MotionParser)
        let p1Rows = parser.commands.commands.filter { $0.fighterID == "missing_pick" }
        XCTAssertFalse(p1Rows.isEmpty, "fallback commands must be keyed by the roster pick")
        XCTAssertTrue(p1Rows.contains { $0.moveID == "sp_qcf" })
        XCTAssertFalse(parser.commands.commands.contains { $0.fighterID == "greybox" })
        XCTAssertTrue(parser.commands.commands.contains { $0.fighterID == "bruno" })
    }
}
