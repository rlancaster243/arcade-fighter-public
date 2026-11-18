import AppLogic
import FightCore
import Combine
import Foundation

@MainActor
final class InputCoordinator: ObservableObject {
    @Published private(set) var session: InputMapSession
    @Published var keyTest = KeyTestModel()
    @Published var showKeyTest = false
    @Published private(set) var gamepadConnected = false

    private let keyboard = KeyboardInputAdapter()
    private let gamepad = GameControllerInputAdapter()

    init() {
        let settings = InputRemapStore.load()
        session = InputMapSession(settings: settings)
        wireAdapters()
    }

    func persistSettings() {
        InputRemapStore.save(session.settings)
    }

    func setPlayerTwoLayout(_ layout: PlayerTwoKeyboardLayout) {
        session.settings.applyPlayerTwoLayout(layout)
        session.syncBindingsFromSettings()
        persistSettings()
    }

    func beginRemap(player: PlayerSlot, slot: KeyRemapSlot, captureNextKey: @escaping (UInt16) -> Void) {
        let priorDown = keyboard.onKeyDown
        keyboard.onKeyDown = { [weak self] keyCode in
            guard let self else { return }
            captureNextKey(keyCode)
            self.session.settings.remapKey(player: player, slot: slot, to: keyCode)
            self.session.syncBindingsFromSettings()
            self.persistSettings()
            self.keyboard.onKeyDown = priorDown
        }
    }

    func framesForTick() -> [InputFrame] {
        session.framesForTick(gamepadOverridesP1: gamepadConnected)
    }

    private func wireAdapters() {
        keyboard.onKeyDown = { [weak self] keyCode in
            self?.handleKeyDown(keyCode)
        }
        keyboard.onKeyUp = { [weak self] keyCode in
            self?.handleKeyUp(keyCode)
        }
        gamepad.faceMap = session.settings.gamepadFaceMap
        gamepad.onSample = { [weak self] direction, pressed in
            Task { @MainActor in
                self?.applyGamepad(direction: direction, pressed: pressed)
            }
        }
        keyboard.startMonitoring()
        gamepad.start()
    }

    private func handleKeyDown(_ keyCode: UInt16) {
        session.keyDown(keyCode)
        recordKeyTest(keyCode: keyCode, isKeyDown: true)
    }

    private func handleKeyUp(_ keyCode: UInt16) {
        session.keyUp(keyCode)
        recordKeyTest(keyCode: keyCode, isKeyDown: false)
    }

    private func recordKeyTest(keyCode: UInt16, isKeyDown: Bool) {
        let player = session.owner(for: keyCode)
        let slot = player.flatMap { session.remapSlot(for: keyCode, player: $0) }
        keyTest.record(
            keyCode: keyCode,
            label: KeyboardInputAdapter.label(for: keyCode),
            player: player,
            slot: slot,
            isKeyDown: isKeyDown
        )
    }

    private func applyGamepad(direction: Direction, pressed: Set<GamepadFaceButton>) {
        gamepadConnected = true
        session.gamepad.setStickDirection(direction)
        for face in GamepadFaceButton.allCases {
            session.gamepad.setFaceButton(face, pressed: pressed.contains(face))
        }
    }
}