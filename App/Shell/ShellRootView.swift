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
        GeometryReader { geo in
            let w = Int(geo.size.width.rounded(.down))
            let h = Int(geo.size.height.rounded(.down))
            let forced = model.state.preferences.display.wantsFullscreen
                ? nil
                : model.state.preferences.display.windowIntegerScale
            let vp = DisplayLayout.viewport(viewWidth: w, viewHeight: h, forcedScale: forced)
            SpriteView(scene: greyboxScene(snapshot: snapshot))
                .interpolation(.none)
                .frame(width: CGFloat(vp.contentWidth), height: CGFloat(vp.contentHeight))
                .position(
                    x: CGFloat(vp.offsetX) + CGFloat(vp.contentWidth) / 2,
                    y: CGFloat(vp.offsetY) + CGFloat(vp.contentHeight) / 2
                )
        }
        .allowsHitTesting(false)
    }

    private func greyboxScene(snapshot: GameSnapshot) -> SKScene {
        let scene = GreyboxScene(size: CGSize(width: 384, height: 216))
        scene.scaleMode = .resizeFill
        scene.snapshot = snapshot
        return scene
    }
}

#if DEBUG
#Preview {
    ShellRootView()
        .frame(width: 768, height: 432)
}
#endif