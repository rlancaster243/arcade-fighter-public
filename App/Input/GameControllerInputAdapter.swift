import AppLogic
import GameController

/// `GCController` adapter: 0.5 stick deadzone, 8-way direction, X/Y/A/B face map.
final class GameControllerInputAdapter {
    private let deadzone = GamepadDirectionSampler.defaultDeadzone
    var faceMap: GamepadFaceMap = KeyMapDefaults.gamepadFace

    var onSample: ((Direction, Set<GamepadFaceButton>) -> Void)?

    private var observers: [NSObjectProtocol] = []
    private var linkedController: GCController?

    func start() {
        GCController.shouldMonitorBackgroundEvents = true
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .GCControllerDidConnect,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.attachPreferredController()
            }
        )
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .GCControllerDidDisconnect,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.attachPreferredController()
            }
        )
        attachPreferredController()
    }

    func stop() {
        linkedController = nil
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }

    private func attachPreferredController() {
        linkedController = GCController.controllers().first
        linkedController?.extendedGamepad?.valueChangedHandler = { [weak self] gamepad, _ in
            self?.emitSample(from: gamepad)
        }
        if let gamepad = linkedController?.extendedGamepad {
            emitSample(from: gamepad)
        } else {
            onSample?(.neutral, [])
        }
    }

    private func emitSample(from gamepad: GCExtendedGamepad) {
        let stickDirection = GamepadDirectionSampler.direction(
            horizontal: gamepad.leftThumbstick.xAxis.value,
            vertical: gamepad.leftThumbstick.yAxis.value,
            deadzone: deadzone
        )
        let dpadDirection = GamepadDirectionSampler.direction(
            horizontal: gamepad.dpad.xAxis.value,
            vertical: gamepad.dpad.yAxis.value,
            deadzone: deadzone
        )
        let merged = dpadDirection != .neutral ? dpadDirection : stickDirection

        var pressed = Set<GamepadFaceButton>()
        if gamepad.buttonX.isPressed { pressed.insert(.buttonX) }
        if gamepad.buttonY.isPressed { pressed.insert(.buttonY) }
        if gamepad.buttonA.isPressed { pressed.insert(.buttonA) }
        if gamepad.buttonB.isPressed { pressed.insert(.buttonB) }
        onSample?(merged, pressed)
    }

    deinit {
        stop()
    }
}