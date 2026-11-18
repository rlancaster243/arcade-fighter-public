import FightCore

public enum MenuReducer {
    public static func reduce(state: inout MenuShellState, command: MenuCommand) {
        switch state.screen {
        case .title:
            handleTitle(&state, command: command)
        case .mainMenu:
            handleMainMenu(&state, command: command)
        case .arcadeLadder:
            handleArcadeLadder(&state, command: command)
        case .versusSetup:
            handleVersusSetup(&state, command: command)
        case .characterSelect(let context):
            handleCharacterSelect(&state, context: context, command: command)
        case .inMatch:
            handleInMatch(&state, command: command)
        case .matchPaused(let setup):
            handleMatchPaused(&state, setup: setup, command: command)
        case .result(let summary):
            handleResult(&state, summary: summary, command: command)
        case .settings(let pane):
            handleSettings(&state, pane: pane, command: command)
        case .rematchPrompt(let setup):
            handleRematchPrompt(&state, setup: setup, command: command)
        }
    }

    public static func beginMatch(from setup: MatchSetup) -> MenuShellState {
        var state = MenuShellState(screen: .inMatch(setup))
        state.cursor = 0
        return state
    }

  public static func finishMatch(
        state: MenuShellState,
        snapshot: GameSnapshot
    ) -> MenuShellState {
        guard case .inMatch(let setup) = state.screen else { return state }
        let summary = MatchResultSummary(
            setup: setup,
            winner: snapshot.rules.winner,
            p1RoundsWon: snapshot.rules.p1RoundsWon,
            p2RoundsWon: snapshot.rules.p2RoundsWon
        )
        var next = state
        next.screen = .result(summary)
        next.cursor = 0
        return next
    }

    // MARK: - Title

    private static func handleTitle(_ state: inout MenuShellState, command: MenuCommand) {
        switch command {
        case .confirm, .up, .down, .left, .right:
            state.screen = .mainMenu
            state.cursor = 0
        default:
            break
        }
    }

    // MARK: - Main menu

    private static func handleMainMenu(_ state: inout MenuShellState, command: MenuCommand) {
        let itemCount = MenuShellState.MainMenuItem.allCases.count
        switch command {
        case .up:
            state.cursor = wrap(state.cursor - 1, itemCount)
        case .down:
            state.cursor = wrap(state.cursor + 1, itemCount)
        case .confirm:
            guard let item = MenuShellState.MainMenuItem(rawValue: state.cursor) else { return }
            switch item {
            case .arcade:
                state.screen = .arcadeLadder
                state.cursor = 0
            case .versus:
                state.screen = .versusSetup
                state.cursor = 0
            case .settings:
                state.screen = .settings(.display)
                state.settingsPane = .display
                state.cursor = 0
            case .quit:
                state.requestedQuit = true
            }
        case .cancel:
            state.screen = .title
            state.cursor = 0
        default:
            break
        }
    }

    // MARK: - Arcade ladder

    private static func handleArcadeLadder(_ state: inout MenuShellState, command: MenuCommand) {
        switch command {
        case .confirm:
            state.screen = .characterSelect(.arcade(playerFighter: defaultPick()))
            state.characterCursor = 0
        case .cancel:
            state.screen = .mainMenu
            state.cursor = MenuShellState.MainMenuItem.arcade.rawValue
        default:
            break
        }
    }

    // MARK: - Versus setup

    private static func handleVersusSetup(_ state: inout MenuShellState, command: MenuCommand) {
        switch command {
        case .confirm:
            state.screen = .characterSelect(.versus(selecting: .p1, p1: nil, p2: nil))
            state.characterCursor = 0
        case .cancel:
            state.screen = .mainMenu
            state.cursor = MenuShellState.MainMenuItem.versus.rawValue
        default:
            break
        }
    }

    // MARK: - Character select

    private static func handleCharacterSelect(
        _ state: inout MenuShellState,
        context: CharacterSelectContext,
        command: MenuCommand
    ) {
        let rosterCount = FighterRoster.count
        switch command {
        case .left:
            state.characterCursor = wrap(state.characterCursor - 1, rosterCount)
        case .right:
            state.characterCursor = wrap(state.characterCursor + 1, rosterCount)
        case .confirm:
            let pick = fighterPick(at: state.characterCursor)
            switch context {
            case .arcade:
                let run = ArcadeRunState()
                let opponent = fighterPick(at: FighterRoster.index(of: FighterRoster.id(at: run.opponentIndex)))
                let setup = MatchSetup(
                    mode: .arcade,
                    p1: pick,
                    p2: opponent,
                    stageIndex: 0,
                    arcadeRun: run,
                    difficulty: run.currentDifficulty
                )
                state.screen = .inMatch(setup)
            case .versus(selecting: .p1, _, _):
                state.screen = .characterSelect(.versus(selecting: .p2, p1: pick, p2: nil))
            case .versus(selecting: .p2, let p1, _):
                guard let p1 else {
                    state.screen = .characterSelect(.versus(selecting: .p1, p1: nil, p2: nil))
                    return
                }
                let setup = MatchSetup(mode: .versus, p1: p1, p2: pick)
                state.screen = .inMatch(setup)
            }
        case .cancel:
            switch context {
            case .arcade:
                state.screen = .arcadeLadder
            case .versus:
                state.screen = .versusSetup
            }
            state.cursor = 0
        default:
            break
        }
    }

    // MARK: - In match

    private static func handleInMatch(_ state: inout MenuShellState, command: MenuCommand) {
        guard command == .pause || command == .cancel else { return }
        guard case .inMatch(let setup) = state.screen else { return }
        state.screen = .matchPaused(setup)
        state.cursor = 0
    }

    private static func handleMatchPaused(
        _ state: inout MenuShellState,
        setup: MatchSetup,
        command: MenuCommand
    ) {
        switch command {
        case .pause, .cancel:
            state.screen = .inMatch(setup)
        default:
            break
        }
    }

    // MARK: - Result

    private static func handleResult(
        _ state: inout MenuShellState,
        summary: MatchResultSummary,
        command: MenuCommand
    ) {
        let itemCount = MenuShellState.ResultMenuItem.allCases.count
        switch command {
        case .up:
            state.cursor = wrap(state.cursor - 1, itemCount)
        case .down:
            state.cursor = wrap(state.cursor + 1, itemCount)
        case .confirm:
            guard let item = MenuShellState.ResultMenuItem(rawValue: state.cursor) else { return }
            switch item {
            case .rematch:
                if summary.setup.mode == .arcade,
                   summary.winner == .p1,
                   let run = summary.setup.arcadeRun,
                   !run.isComplete
                {
                    MenuReducer.advanceArcadeAfterWin(state: &state, summary: summary)
                } else {
                    state.screen = .rematchPrompt(summary.setup)
                    state.cursor = 0
                }
            case .characterSelect:
                if summary.setup.mode == .arcade {
                    state.screen = .characterSelect(.arcade(playerFighter: summary.setup.p1))
                } else {
                    state.screen = .characterSelect(.versus(selecting: .p1, p1: nil, p2: nil))
                }
                state.characterCursor = summary.setup.p1.rosterIndex
            case .mainMenu:
                state.screen = .mainMenu
                state.cursor = 0
            }
        case .cancel:
            state.screen = .mainMenu
            state.cursor = 0
        default:
            break
        }
    }

    // MARK: - Rematch prompt

    private static func handleRematchPrompt(
        _ state: inout MenuShellState,
        setup: MatchSetup,
        command: MenuCommand
    ) {
        switch command {
        case .confirm:
            state.screen = .inMatch(setup)
        case .cancel:
            if setup.mode == .arcade {
                state.screen = .arcadeLadder
            } else {
                state.screen = .mainMenu
                state.cursor = MenuShellState.MainMenuItem.versus.rawValue
            }
        default:
            break
        }
    }

    // MARK: - Settings

    private static func handleSettings(
        _ state: inout MenuShellState,
        pane: SettingsPane,
        command: MenuCommand
    ) {
        let rows = MenuShellState.SettingsRow.allCases.count
        switch command {
        case .up:
            state.cursor = wrap(state.cursor - 1, rows)
        case .down:
            state.cursor = wrap(state.cursor + 1, rows)
        case .left, .right:
            guard let row = MenuShellState.SettingsRow(rawValue: state.cursor) else { return }
            adjustSetting(&state, row: row, command: command)
        case .confirm:
            guard let row = MenuShellState.SettingsRow(rawValue: state.cursor) else { return }
            if row == .back {
                state.screen = .mainMenu
                state.cursor = MenuShellState.MainMenuItem.settings.rawValue
            } else {
                adjustSetting(&state, row: row, command: command)
            }
        case .cancel:
            state.screen = .mainMenu
            state.cursor = MenuShellState.MainMenuItem.settings.rawValue
        default:
            break
        }
        state.screen = .settings(pane)
    }

    private static func adjustSetting(
        _ state: inout MenuShellState,
        row: MenuShellState.SettingsRow,
        command: MenuCommand
    ) {
        let delta = command == .right ? 1 : -1
        switch row {
        case .fullscreen:
            state.preferences.display.wantsFullscreen.toggle()
        case .windowScale:
            let next = state.preferences.display.windowIntegerScale + delta
            state.preferences.display.windowIntegerScale = min(6, max(1, next))
        case .volume:
            let next = state.preferences.audio.masterVolumePermille + (delta * 100)
            state.preferences.audio = AudioPreferences(masterVolumePermille: next)
        case .back:
            break
        }
    }

    // MARK: - Arcade progression

    public static func advanceArcadeAfterWin(
        state: inout MenuShellState,
        summary: MatchResultSummary
    ) {
        guard summary.setup.mode == .arcade, summary.winner == .p1 else { return }
        guard var run = summary.setup.arcadeRun else { return }
        run.victories += 1
        run.opponentIndex += 1
        if run.isComplete {
            state.screen = .mainMenu
            state.cursor = MenuShellState.MainMenuItem.arcade.rawValue
            return
        }
        let nextOpponent = fighterPick(at: FighterRoster.index(of: FighterRoster.id(at: run.opponentIndex)))
        let nextSetup = MatchSetup(
            mode: .arcade,
            p1: summary.setup.p1,
            p2: nextOpponent,
            stageIndex: run.opponentIndex,
            arcadeRun: run,
            difficulty: run.currentDifficulty
        )
        state.screen = .inMatch(nextSetup)
    }

    // MARK: - Helpers

    private static func defaultPick() -> FighterPick {
        fighterPick(at: 0)
    }

    private static func fighterPick(at index: Int) -> FighterPick {
        let id = FighterRoster.id(at: index)
        return FighterPick(rosterIndex: FighterRoster.index(of: id), id: id)
    }

    private static func wrap(_ value: Int, _ count: Int) -> Int {
        guard count > 0 else { return 0 }
        let rem = value % count
        return rem >= 0 ? rem : rem + count
    }
}