import AppLogic
import SwiftUI

struct KeyTestScreen: View {
    @ObservedObject var input: InputCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Key Test")
                    .font(.headline)
                Spacer()
                Button("Clear") { input.keyTest.clear() }
                Button("Done") { input.showKeyTest = false }
            }

            Picker("P2 button layout", selection: layoutBinding) {
                Text("Numpad 4/5/1/2").tag(PlayerTwoKeyboardLayout.numpad)
                Text("Alternate I/O/K/L").tag(PlayerTwoKeyboardLayout.alternate)
            }
            .pickerStyle(.segmented)

            Text("Press keys or use a gamepad. Auto-repeat is ignored.")
                .font(.caption)
                .foregroundStyle(.secondary)

            List(input.keyTest.recent) { event in
                HStack {
                    Text(event.isKeyDown ? "↓" : "↑")
                        .frame(width: 16)
                    Text(event.label)
                        .monospacedDigit()
                    if let player = event.player {
                        Text(player == .p1 ? "P1" : "P2")
                    }
                    if let slot = event.slot {
                        Text(slot.rawValue)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(String(format: "0x%02X", event.keyCode))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(minWidth: 420, minHeight: 360)
    }

    private var layoutBinding: Binding<PlayerTwoKeyboardLayout> {
        Binding(
            get: { input.session.settings.playerTwoLayout },
            set: { input.setPlayerTwoLayout($0) }
        )
    }
}