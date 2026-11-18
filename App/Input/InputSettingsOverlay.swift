import AppLogic
import SwiftUI

struct InputSettingsOverlay: View {
    @ObservedObject var input: InputCoordinator
    var canOpenKeyTest: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Input (L8)")
                .font(.caption.bold())
            Button("Key test…") {
                guard canOpenKeyTest else { return }
                input.showKeyTest = true
            }
            .disabled(!canOpenKeyTest)
            Text("P1: WASD + F/G/H/J")
                .font(.caption2)
            Text(p2Label)
                .font(.caption2)
            Text("Gamepad: X/Y/A/B → LP/HP/LK/HK")
                .font(.caption2)
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var p2Label: String {
        switch input.session.settings.playerTwoLayout {
        case .numpad:
            "P2: Arrows + Numpad 4/5/1/2"
        case .alternate:
            "P2: Arrows + I/O/K/L"
        }
    }
}