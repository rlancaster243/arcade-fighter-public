import AppLogic
import SwiftUI

struct TitleScreenView: View {
    let onAdvance: () -> Void

    var body: some View {
        MenuBackground(title: "ARCADE FIGHTER") {
            VStack(spacing: 12) {
                Text("Press Enter")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Button("Start", action: onAdvance)
                    .keyboardShortcut(.defaultAction)
            }
            MenuHintBar(text: "Enter · any direction")
        }
    }
}

struct MainMenuView: View {
    let cursor: Int

    var body: some View {
        MenuBackground(title: "MAIN MENU") {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(MenuShellState.MainMenuItem.allCases, id: \.rawValue) { item in
                    MenuListRow(label: item.label, selected: item.rawValue == cursor)
                }
            }
            MenuHintBar(text: "↑↓ move · Enter confirm · Esc back")
        }
    }
}

struct ArcadeLadderView: View {
    var body: some View {
        MenuBackground(title: "ARCADE LADDER") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0 ..< ArcadeRunState.ladderLength, id: \.self) { index in
                    let diff = ArcadeRunState().difficulty(forOpponentAt: index)
                    HStack {
                        Text("MATCH \(index + 1)")
                        Spacer()
                        Text(String(describing: diff).uppercased())
                            .foregroundStyle(.orange)
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                Text("Win 3 fights to clear the ladder.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            MenuHintBar(text: "Enter · select your fighter")
        }
    }
}

struct VersusSetupView: View {
    var body: some View {
        MenuBackground(title: "VERSUS") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Local 2-player on one keyboard.")
                Text("P1: WASD + F/G/H/J")
                Text("P2: Arrows + numpad 4/5/1/2")
            }
            .font(.system(size: 15, design: .monospaced))
            .foregroundStyle(.white)
            MenuHintBar(text: "Enter · character select")
        }
    }
}

struct CharacterSelectView: View {
    let context: CharacterSelectContext
    let cursor: Int

    var body: some View {
        MenuBackground(title: "SELECT FIGHTER") {
            VStack(alignment: .leading, spacing: 12) {
                switch context {
                case .arcade:
                    Text("Player — choose your fighter")
                case .versus(let selecting, let p1, _):
                    Text(selecting == .p1 ? "Player 1" : "Player 2")
                    if let p1 {
                        Text("P1: \(p1.id)")
                            .foregroundStyle(.cyan)
                    }
                }
                HStack(spacing: 16) {
                    ForEach(0 ..< FighterRoster.count, id: \.self) { index in
                        let selected = index == cursor
                        Text(FighterRoster.id(at: index))
                            .padding(8)
                            .background(selected ? Color.white.opacity(0.2) : Color.clear)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(selected ? Color.yellow : Color.gray, lineWidth: 1))
                    }
                }
            }
            MenuHintBar(text: "←→ pick · Enter confirm · Esc back")
        }
    }
}

struct SettingsView: View {
    let preferences: AppPreferences
    let cursor: Int
    var onKeyTest: (() -> Void)?

    var body: some View {
        MenuBackground(title: "SETTINGS") {
            VStack(alignment: .leading, spacing: 6) {
                settingsRow(
                    "Fullscreen",
                    value: preferences.display.wantsFullscreen ? "ON" : "OFF",
                    selected: cursor == MenuShellState.SettingsRow.fullscreen.rawValue
                )
                settingsRow(
                    "Window scale",
                    value: "\(preferences.display.windowIntegerScale)x",
                    selected: cursor == MenuShellState.SettingsRow.windowScale.rawValue
                )
                settingsRow(
                    "Master volume",
                    value: "\(preferences.audio.masterVolumePermille / 10)%",
                    selected: cursor == MenuShellState.SettingsRow.volume.rawValue
                )
                MenuListRow(
                    label: "Back",
                    selected: cursor == MenuShellState.SettingsRow.back.rawValue
                )
                if let onKeyTest {
                    Button("Key test…", action: onKeyTest)
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                }
            }
            MenuHintBar(text: "↑↓ row · ←→ change · Enter back row")
        }
    }

    private func settingsRow(_ title: String, value: String, selected: Bool) -> some View {
        HStack {
            MenuListRow(label: title, selected: selected)
            Spacer()
            Text(value)
                .foregroundStyle(.orange)
        }
    }
}

struct MatchResultView: View {
    let summary: MatchResultSummary
    let cursor: Int

    var body: some View {
        let winnerText = summary.winner.map { "Player \($0 == .p1 ? 1 : 2) wins" } ?? "Draw"
        MenuBackground(title: "RESULT") {
            VStack(alignment: .leading, spacing: 8) {
                Text(winnerText)
                    .font(.title3.bold())
                Text("Rounds  P1 \(summary.p1RoundsWon) – \(summary.p2RoundsWon) P2")
                Divider().background(.gray)
                ForEach(MenuShellState.ResultMenuItem.allCases, id: \.rawValue) { item in
                    MenuListRow(label: item.label(for: summary), selected: item.rawValue == cursor)
                }
            }
            MenuHintBar(text: "↑↓ · Enter")
        }
    }
}

struct MatchPausedView: View {
    let setup: MatchSetup
    @ObservedObject var input: InputCoordinator

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 10) {
                Text("PAUSED")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Text("\(setup.p1.id) vs \(setup.p2.id)")
                    .foregroundStyle(.white.opacity(0.9))
                Text("P or Esc — resume")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.vertical, 28)
            .padding(.horizontal, 36)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
            InputSettingsOverlay(input: input)
                .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.35))
        .allowsHitTesting(true)
    }
}

struct RematchPromptView: View {
    let setup: MatchSetup

    var body: some View {
        MenuBackground(title: "REMATCH?") {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(setup.p1.id) vs \(setup.p2.id)")
                Text("Enter — fight again")
                Text("Esc — leave match")
            }
            .foregroundStyle(.white)
        }
    }
}