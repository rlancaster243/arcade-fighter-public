import AppLogic
import FightCore
import Foundation

@MainActor
final class MenuShellModel: ObservableObject {
    @Published private(set) var state: MenuShellState
    @Published var matchSnapshot: GameSnapshot?
    /// Content bundle each slot actually loaded (differs from the pick after a load fallback).
    @Published var matchContentIDs: [String] = []
    /// Stage the running match is on; drives the background layers.
    @Published var matchStageID: String = "stage1"
    @Published var contentLoadNotices: [String] = []

    init(state: MenuShellState = .initial) {
        self.state = state
    }

    func send(_ command: MenuCommand) {
        var next = state
        if next.alertMessage != nil {
            next.alertMessage = nil
        }
        MenuReducer.reduce(state: &next, command: command)
        applyTransition(from: state, to: next)
        state = next
    }

    func handleMatchStartFailure(_ error: Error) {
        matchSnapshot = nil
        matchContentIDs = []
        var next = state
        let message = (error as? CustomStringConvertible)?.description ?? String(describing: error)
        MenuReducer.abortFailedMatchStart(state: &next, message: message)
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
            if shouldBootstrapMatch(from: old.screen, to: new.screen) {
                matchSnapshot = MatchBootstrap.snapshot(for: setup)
                matchContentIDs = []
            }
        case .matchPaused, .result:
            break
        case .title, .mainMenu, .arcadeLadder, .versusSetup, .characterSelect, .settings, .rematchPrompt:
            matchSnapshot = nil
            matchContentIDs = []
        }
    }

    private func shouldBootstrapMatch(from old: MenuScreen, to new: MenuScreen) -> Bool {
        guard case .inMatch = new else { return false }
        switch old {
        case .inMatch, .matchPaused:
            return false
        default:
            return true
        }
    }

    func setContentLoadNotices(_ notices: [String]) {
        contentLoadNotices = notices
    }

    func appendContentLoadNotices(_ notices: [String]) {
        guard !notices.isEmpty else { return }
        contentLoadNotices.append(contentsOf: notices)
    }

    func clearContentLoadNotices() {
        contentLoadNotices = []
    }

    var preferences: AppPreferences {
        get { state.preferences }
        set { state.preferences = newValue }
    }
}