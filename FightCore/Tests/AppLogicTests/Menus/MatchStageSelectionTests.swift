import AppLogic
import XCTest
import FightCore

final class MatchStageSelectionTests: XCTestCase {
    func testMenuStageIndexZeroSelectsStage1() throws {
        XCTAssertEqual(StageBoundsLoader.stageID(forSetupIndex: 0), "stage1")
        let bounds = try StageBoundsLoader.playBounds(stageId: "stage1")
        XCTAssertEqual(bounds.playLeftPx, 20 - 192)
        XCTAssertEqual(bounds.playRightPx, 364 - 192)
    }

    func testMenuStageIndexOneSelectsStage2() throws {
        let setup = MatchSetup(
            mode: .versus,
            p1: FighterPick(rosterIndex: 0, id: "greybox"),
            p2: FighterPick(rosterIndex: 0, id: "greybox"),
            stageIndex: 1
        )
        XCTAssertEqual(StageBoundsLoader.stageID(forSetupIndex: setup.stageIndex), "stage2")

        let stage2 = try StageBoundsLoader.playBounds(stageId: "stage2")
        let stage1 = try StageBoundsLoader.playBounds(stageId: "stage1")
        XCTAssertNotEqual(stage2.playLeftPx, stage1.playLeftPx)
        XCTAssertEqual(stage2.playLeftPx, -192)
        XCTAssertEqual(stage2.playRightPx, 192)
    }

    func testArcadeAdvanceUsesOpponentIndexAsStageIndex() throws {
        var state = MenuShellState(screen: .inMatch(MatchSetup(
            mode: .arcade,
            p1: FighterPick(rosterIndex: 0, id: "kestrel"),
            p2: FighterPick(rosterIndex: 1, id: "bruno"),
            stageIndex: 0,
            arcadeRun: ArcadeRunState(opponentIndex: 0, victories: 0)
        )))
        let summary = MatchResultSummary(
            setup: MatchSetup(
                mode: .arcade,
                p1: FighterPick(rosterIndex: 0, id: "kestrel"),
                p2: FighterPick(rosterIndex: 1, id: "bruno"),
                stageIndex: 0,
                arcadeRun: ArcadeRunState(opponentIndex: 0, victories: 0)
            ),
            winner: .p1,
            p1RoundsWon: 2,
            p2RoundsWon: 0
        )
        MenuReducer.advanceArcadeAfterWin(state: &state, summary: summary)
        guard case .inMatch(let next) = state.screen else {
            return XCTFail("expected next arcade match")
        }
        XCTAssertEqual(next.stageIndex, 1)
        XCTAssertEqual(StageBoundsLoader.stageID(forSetupIndex: next.stageIndex), "stage2")
    }
}