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

    public init() {}

    public var body: some View {
        ZStack {
            menuLayer
            if let snapshot = model.matchSnapshot {
                matchLayer(snapshot: snapshot)
            }
        }
        .frame(minWidth: 384, minHeight: 216)
        .windowPreferences(model.state.preferences)
        #if os(macOS)
        .background(MenuKeyboardBridge { model.send($0) })
        .onChange(of: model.state.requestedQuit) { _, quit in
            if quit { NSApplication.shared.terminate(nil) }
        }
        #endif
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