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
        case .inMatch, .matchPaused, .result:
            return model.matchSnapshot != nil
        default:
            return false
        }
    }

    private var showsMenuInputOverlay: Bool {
        switch model.state.screen {
        case .inMatch, .matchPaused:
            return false
        default:
            return true
        }
    }

    public var body: some View {
        ZStack {
            if let snapshot = model.matchSnapshot, showsMatchView {
                matchLayer(snapshot: snapshot)
            }
            menuLayer
            if case .matchPaused(let setup) = model.state.screen {
                MatchPausedView(setup: setup, input: input)
            }
            MatchTickView(isActive: isFighting) { date in
                guard isFighting else { return }
                matchSession.advance(to: date, input: input, model: model, sfx: sfx)
            }
        }
        .frame(minWidth: 384, minHeight: 216)
        .windowPreferences(model.state.preferences)
        .overlay(alignment: .topTrailing) {
            if showsMenuInputOverlay {
                InputSettingsOverlay(input: input)
                    .padding(12)
            }
        }
        .overlay(alignment: .bottom) {
            contentNoticeBanner
        }
        .onAppear {
            let audioNotices = sfx.preloadIfNeeded()
            if !audioNotices.isEmpty {
                model.appendContentLoadNotices(audioNotices)
            }
            syncMatchSessionIfNeeded()
        }
        .onChange(of: model.state.screen) { _, _ in
            syncMatchSessionIfNeeded()
            if !isFighting && !showsMatchView {
                model.clearContentLoadNotices()
            }
        }
        .sheet(isPresented: $input.showKeyTest) {
            KeyTestScreen(input: input)
        }
        #if os(macOS)
        .background(MenuKeyboardBridge { model.send($0) })
        .onChange(of: model.state.requestedQuit) { _, quit in
            if quit { NSApplication.shared.terminate(nil) }
        }
        #endif
    }

    @ViewBuilder
    private var contentNoticeBanner: some View {
        if !model.contentLoadNotices.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(model.contentLoadNotices, id: \.self) { line in
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
        }
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
            SettingsView(
                preferences: model.state.preferences,
                cursor: model.state.cursor,
                onKeyTest: { input.showKeyTest = true }
            )
        case .result(let summary):
            MatchResultView(summary: summary, cursor: model.state.cursor)
        case .rematchPrompt(let setup):
            RematchPromptView(setup: setup)
        case .matchPaused, .inMatch:
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
                windowIntegerScale: display.windowIntegerScale,
                onAtlasLoadNotice: { line in
                    Task { @MainActor in
                        model.appendContentLoadNotices([line])
                    }
                }
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