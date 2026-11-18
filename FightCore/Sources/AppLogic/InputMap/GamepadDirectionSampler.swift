import FightCore

/// Converts stick / D-pad vectors to 8-way directions (adapter supplies normalised axes).
public enum GamepadDirectionSampler {
    public static let defaultDeadzone = 0.5

    public static func direction(
        horizontal: Double,
        vertical: Double,
        deadzone: Double = defaultDeadzone
    ) -> Direction {
        let ax = abs(horizontal) >= deadzone
        let ay = abs(vertical) >= deadzone
        let left = ax && horizontal < 0
        let right = ax && horizontal > 0
        let up = ay && vertical > 0
        let down = ay && vertical < 0
        return DirectionComposer.compose(up: up, down: down, left: left, right: right)
    }
}

/// Face buttons → `InputFrame` using a remap table.
public struct GamepadInputSampler: Sendable, Equatable {
    public var faceMap: GamepadFaceMap
    public private(set) var pressed: Set<GamepadFaceButton> = []
    public var stickDirection: Direction = .neutral

    public init(faceMap: GamepadFaceMap) {
        self.faceMap = faceMap
    }

    public mutating func setFaceButton(_ button: GamepadFaceButton, pressed isPressed: Bool) {
        if isPressed {
            pressed.insert(button)
        } else {
            pressed.remove(button)
        }
    }

    public mutating func setStickDirection(_ direction: Direction) {
        stickDirection = direction
    }

    public func sampleFrame() -> InputFrame {
        var frame = InputFrame(direction: stickDirection)
        if pressed.contains(faceMap.lightPunch) { frame.set(.lightPunch, pressed: true) }
        if pressed.contains(faceMap.heavyPunch) { frame.set(.heavyPunch, pressed: true) }
        if pressed.contains(faceMap.lightKick) { frame.set(.lightKick, pressed: true) }
        if pressed.contains(faceMap.heavyKick) { frame.set(.heavyKick, pressed: true) }
        return frame
    }
}