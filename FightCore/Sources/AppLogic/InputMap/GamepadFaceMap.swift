/// Logical face-button slots (platform adapters map these to `GCControllerElement`).
public enum GamepadFaceButton: UInt8, Sendable, Equatable, Hashable, Codable, CaseIterable {
    case buttonA = 0
    case buttonB = 1
    case buttonX = 2
    case buttonY = 3
}

public struct GamepadFaceMap: Sendable, Equatable, Hashable, Codable {
    public var lightPunch: GamepadFaceButton
    public var heavyPunch: GamepadFaceButton
    public var lightKick: GamepadFaceButton
    public var heavyKick: GamepadFaceButton

    public init(
        lightPunch: GamepadFaceButton,
        heavyPunch: GamepadFaceButton,
        lightKick: GamepadFaceButton,
        heavyKick: GamepadFaceButton
    ) {
        self.lightPunch = lightPunch
        self.heavyPunch = heavyPunch
        self.lightKick = lightKick
        self.heavyKick = heavyKick
    }
}