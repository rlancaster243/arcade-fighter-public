import AppLogic
import FightCore
import Foundation

@MainActor
final class MenuShellModel: ObservableObject {
    @Published private(set) var state: MenuShellState
    @Published var matchSnapshot: GameSnapshot?

    init(state: MenuShellState = .initial) {
        self.state = state
    }

    func send(_ command: MenuCommand) {
        var next = state
        MenuReducer.reduce(state: &next, command: command)
        applyTransition(from: state, to: next)
        state = next
    }

    func endMatch(snapshot: GameSnapshot) {
        let next = MenuReducer.finishMatch(state: state, snapshot: snapshot)
        applyTransition(from: state, to: next)
        state = next
    }

    private func applyTransition(from old: MenuShellState, to new: MenuShellState) {
        switch new.screen {
        case .inMatch(let setup):
            if case .inMatch = old.screen {
                break
            }
            matchSnapshot = MatchBootstrap.snapshot(for: setup)
        case .title, .mainMenu, .arcadeLadder, .versusSetup, .characterSelect, .result, .settings, .rematchPrompt:
            if case .inMatch = old.screen {
                matchSnapshot = nil
            }
        }
    }

    var preferences: AppPreferences {
        get { state.preferences }
        set { state.preferences = newValue }
    }
}