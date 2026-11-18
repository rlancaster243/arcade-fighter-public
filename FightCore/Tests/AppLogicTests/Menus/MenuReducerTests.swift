import XCTest
@testable import AppLogic
import FightCore

final class MenuReducerTests: XCTestCase {
    func testTitleConfirmOpensMainMenu() {
        var state = MenuShellState.initial
        MenuReducer.reduce(state: &state, command: .confirm)
        XCTAssertEqual(state.screen, .mainMenu)
    }

    func testMainMenuArcadeFlow() {
        var state = MenuShellState(screen: .mainMenu, cursor: 0)
        MenuReducer.reduce(state: &state, command: .confirm)
        XCTAssertEqual(state.screen, .arcadeLadder)

        MenuReducer.reduce(state: &state, command: .confirm)
        guard case .characterSelect(.arcade) = state.screen else {
            return XCTFail("expected arcade character select")
        }

        MenuReducer.reduce(state: &state, command: .confirm)
        guard case .inMatch(let setup) = state.screen else {
            return XCTFail("expected in-match")
        }
        XCTAssertEqual(setup.mode, .arcade)
        XCTAssertEqual(setup.p1.id, "greybox")
    }

    func testVersusTwoStepCharacterSelect() {
        var state = MenuShellState(screen: .mainMenu, cursor: 1)
        MenuReducer.reduce(state: &state, command: .confirm)
        XCTAssertEqual(state.screen, .versusSetup)

        MenuReducer.reduce(state: &state, command: .confirm)
        guard case .characterSelect(.versus(selecting: .p1, _, _)) = state.screen else {
            return XCTFail("expected P1 select")
        }

        MenuReducer.reduce(state: &state, command: .confirm)
        guard case .characterSelect(.versus(selecting: .p2, let p1, _)) = state.screen else {
            return XCTFail("expected P2 select")
        }
        XCTAssertNotNil(p1)

        MenuReducer.reduce(state: &state, command: .confirm)
        guard case .inMatch(let setup) = state.screen else {
            return XCTFail("expected match")
        }
        XCTAssertEqual(setup.mode, .versus)
    }

    func testSettingsFullscreenToggle() {
        var state = MenuShellState(
            screen: .settings(.display),
            preferences: AppPreferences(),
            cursor: MenuShellState.SettingsRow.fullscreen.rawValue
        )
        XCTAssertFalse(state.preferences.display.wantsFullscreen)
        MenuReducer.reduce(state: &state, command: .right)
        XCTAssertTrue(state.preferences.display.wantsFullscreen)
    }

    func testResultRematch() {
        let setup = MatchSetup(
            mode: .versus,
            p1: FighterPick(rosterIndex: 0, id: "greybox"),
            p2: FighterPick(rosterIndex: 0, id: "greybox")
        )
        let summary = MatchResultSummary(setup: setup, winner: .p1, p1RoundsWon: 2, p2RoundsWon: 0)
        var state = MenuShellState(screen: .result(summary), cursor: 0)
        MenuReducer.reduce(state: &state, command: .confirm)
        guard case .rematchPrompt(let rematchSetup) = state.screen else {
            return XCTFail("expected rematch prompt")
        }
        XCTAssertEqual(rematchSetup, setup)

        MenuReducer.reduce(state: &state, command: .confirm)
        guard case .inMatch = state.screen else {
            return XCTFail("expected in-match after rematch confirm")
        }
    }

    func testFinishMatchFromSnapshot() {
        var snap = SimulationBootstrap.greyboxMatch()
        snap.rules.winner = .p1
        snap.rules.p1RoundsWon = 2
        let setup = MatchSetup(
            mode: .versus,
            p1: FighterPick(rosterIndex: 0, id: "greybox"),
            p2: FighterPick(rosterIndex: 0, id: "greybox")
        )
        var state = MenuShellState(screen: .inMatch(setup))
        state = MenuReducer.finishMatch(state: state, snapshot: snap)
        guard case .result(let summary) = state.screen else {
            return XCTFail("expected result")
        }
        XCTAssertEqual(summary.winner, .p1)
        XCTAssertEqual(summary.p1RoundsWon, 2)
    }

    func testArcadeLadderAdvance() {
        let setup = MatchSetup(
            mode: .arcade,
            p1: FighterPick(rosterIndex: 0, id: "greybox"),
            p2: FighterPick(rosterIndex: 0, id: "greybox"),
            arcadeRun: ArcadeRunState(opponentIndex: 0, victories: 0),
            difficulty: .easy
        )
        let summary = MatchResultSummary(setup: setup, winner: .p1, p1RoundsWon: 2, p2RoundsWon: 0)
        var state = MenuShellState(screen: .result(summary), cursor: 0)
        MenuReducer.reduce(state: &state, command: .confirm)
        guard case .inMatch(let next) = state.screen else {
            return XCTFail("expected next arcade match")
        }
        XCTAssertEqual(next.arcadeRun?.opponentIndex, 1)
        XCTAssertEqual(next.difficulty, .normal)
    }

    func testQuitRequest() {
        var state = MenuShellState(screen: .mainMenu, cursor: MenuShellState.MainMenuItem.quit.rawValue)
        MenuReducer.reduce(state: &state, command: .confirm)
        XCTAssertTrue(state.requestedQuit)
    }

    func testInMatchPauseAndResume() {
        let setup = MatchSetup(
            mode: .versus,
            p1: FighterPick(rosterIndex: 0, id: "greybox"),
            p2: FighterPick(rosterIndex: 0, id: "greybox")
        )
        var state = MenuShellState(screen: .inMatch(setup))
        MenuReducer.reduce(state: &state, command: .pause)
        guard case .matchPaused(let pausedSetup) = state.screen else {
            return XCTFail("expected paused")
        }
        XCTAssertEqual(pausedSetup, setup)

        MenuReducer.reduce(state: &state, command: .cancel)
        guard case .inMatch(let resumed) = state.screen else {
            return XCTFail("expected resume")
        }
        XCTAssertEqual(resumed, setup)
    }
}