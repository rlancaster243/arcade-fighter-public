import AppLogic
import FightCore
import SpriteKit
import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Root shell: menus, match preview, window/fullscreen preferences. Wire from `AppMain` when Phase 0 entry is unfrozen.
public struct ShellRootView: View {
    @StateObject private var model = MenuShellModel()
    @StateObject private var input = InputCoordinator()
    @StateObject private var matchSession = LocalMatchSession()
    @StateObject private var sfx = SFXEventPlayer()

    public init() {}

    private var isFighting: Bool {
        if case .inMatch = model.state.screen { return true }
        return false
    }

    private var showsMatchView: Bool {
        switch model.state.screen {
        case .inMatch, .matchPaused:
            return model.matchSnapshot != nil
        default:
            return false
        }
    }

    public var body: some View {
        ZStack {
            menuLayer
            if let snapshot = model.matchSnapshot, showsMatchView {
                matchLayer(snapshot: snapshot)
            }
            MatchTickView(isActive: isFighting) { date in
                guard isFighting else { return }
                matchSession.advance(to: date, input: input, model: model, sfx: sfx)
            }
        }
        .frame(minWidth: 384, minHeight: 216)
        .windowPreferences(model.state.preferences)
        .overlay(alignment: .topTrailing) {
            if !isFighting && !showsMatchView {
                InputSettingsOverlay(input: input, canOpenKeyTest: !showsMatchView)
                    .padding(12)
            }
        }
        .onAppear {
            sfx.preloadIfNeeded()
            syncMatchSessionIfNeeded()
        }
        .onChange(of: model.state.screen) { _, screen in
            switch screen {
            case .inMatch, .matchPaused:
                input.showKeyTest = false
            default:
                break
            }
            syncMatchSessionIfNeeded()
        }
        .sheet(
            isPresented: Binding(
                get: { input.showKeyTest && !showsMatchView },
                set: { input.showKeyTest = $0 }
            )
        ) {
            KeyTestScreen(input: input)
        }
        #if os(macOS)
        .background(MenuKeyboardBridge { model.send($0) })
        .onChange(of: model.state.requestedQuit) { _, quit in
            if quit { NSApplication.shared.terminate(nil) }
        }
        #endif
    }

    private func syncMatchSessionIfNeeded() {
        switch model.state.screen {
        case .inMatch(let setup):
            if matchSession.isPaused {
                matchSession.resume()
            } else if !matchSession.isRunning {
                let snap = model.matchSnapshot ?? MatchBootstrap.snapshot(for: setup)
                matchSession.start(setup: setup, initialSnapshot: snap, model: model)
            }
        case .matchPaused(let setup):
            if !matchSession.isRunning {
                let snap = model.matchSnapshot ?? MatchBootstrap.snapshot(for: setup)
                matchSession.start(setup: setup, initialSnapshot: snap, model: model)
            }
            matchSession.pause()
        default:
            if matchSession.isRunning {
                matchSession.stop()
            }
        }
    }

    @ViewBuilder
    private var menuLayer: some View {
        switch model.state.screen {
        case .title:
            TitleScreenView { model.send(.confirm) }
        case .mainMenu:
            MainMenuView(cursor: model.state.cursor)
        case .arcadeLadder:
            ArcadeLadderView()
        case .versusSetup:
            VersusSetupView()
        case .characterSelect(let context):
            CharacterSelectView(context: context, cursor: model.state.characterCursor)
        case .settings:
            SettingsView(preferences: model.state.preferences, cursor: model.state.cursor)
        case .result(let summary):
            MatchResultView(summary: summary, cursor: model.state.cursor)
        case .rematchPrompt(let setup):
            RematchPromptView(setup: setup)
        case .matchPaused(let setup):
            MatchPausedView(setup: setup)
        case .inMatch:
            Color.clear
        }
    }

    private func matchLayer(snapshot: GameSnapshot) -> some View {
        let display = model.state.preferences.display
        return GeometryReader { geo in
            MatchPreviewView(
                snapshot: snapshot,
                viewWidth: Int(geo.size.width.rounded(.down)),
                viewHeight: Int(geo.size.height.rounded(.down)),
                wantsFullscreen: display.wantsFullscreen,
                windowIntegerScale: display.windowIntegerScale
            )
        }
        .allowsHitTesting(false)
    }
}

#if DEBUG
#Preview {
    ShellRootView()
        .frame(width: 768, height: 432)
}
#endif