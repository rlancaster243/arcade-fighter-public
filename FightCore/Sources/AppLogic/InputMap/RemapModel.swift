import FightCore

/// Persisted input settings (JSON via app `UserDefaults`; no I/O in this type).
public struct InputRemapSettings: Sendable, Equatable, Codable {
    public static let schemaVersion = 1

    public var schemaVersion: Int
    public var playerOneBindings: PlayerKeyBindings
    public var playerTwoBindings: PlayerKeyBindings
    public var playerTwoLayout: PlayerTwoKeyboardLayout
    public var gamepadFaceMap: GamepadFaceMap

    public init(
        schemaVersion: Int = Self.schemaVersion,
        playerOneBindings: PlayerKeyBindings = KeyMapDefaults.playerOne,
        playerTwoBindings: PlayerKeyBindings? = nil,
        playerTwoLayout: PlayerTwoKeyboardLayout = .numpad,
        gamepadFaceMap: GamepadFaceMap = KeyMapDefaults.gamepadFace
    ) {
        self.schemaVersion = schemaVersion
        self.playerOneBindings = playerOneBindings
        self.playerTwoLayout = playerTwoLayout
        self.playerTwoBindings = playerTwoBindings ?? KeyMapDefaults.playerTwo(layout: playerTwoLayout)
        self.gamepadFaceMap = gamepadFaceMap
    }

    public mutating func applyPlayerTwoLayout(_ layout: PlayerTwoKeyboardLayout) {
        playerTwoLayout = layout
        playerTwoBindings = KeyMapDefaults.playerTwo(layout: layout)
    }

    public mutating func remapKey(
        player: PlayerSlot,
        slot: KeyRemapSlot,
        to keyCode: UInt16
    ) {
        switch player {
        case .p1:
            applyRemap(slot: slot, to: keyCode, bindings: &playerOneBindings)
        case .p2:
            applyRemap(slot: slot, to: keyCode, bindings: &playerTwoBindings)
        }
    }

    private mutating func applyRemap(slot: KeyRemapSlot, to keyCode: UInt16, bindings: inout PlayerKeyBindings) {
        switch slot {
        case .up: bindings.up = keyCode
        case .down: bindings.down = keyCode
        case .left: bindings.left = keyCode
        case .right: bindings.right = keyCode
        case .lightPunch: bindings.lightPunch = keyCode
        case .heavyPunch: bindings.heavyPunch = keyCode
        case .lightKick: bindings.lightKick = keyCode
        case .heavyKick: bindings.heavyKick = keyCode
        }
    }
}

public enum KeyRemapSlot: String, Sendable, Equatable, Hashable, Codable, CaseIterable {
    case up
    case down
    case left
    case right
    case lightPunch
    case heavyPunch
    case lightKick
    case heavyKick
}