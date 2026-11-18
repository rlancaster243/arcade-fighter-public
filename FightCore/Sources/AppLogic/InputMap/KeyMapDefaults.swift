import FightCore

/// Built-in keyboard layouts from the shared brief.
public enum KeyMapDefaults {
    public static let playerOne: PlayerKeyBindings = PlayerKeyBindings(
        up: MacVirtualKeyCode.ansiW.rawValue,
        down: MacVirtualKeyCode.ansiS.rawValue,
        left: MacVirtualKeyCode.ansiA.rawValue,
        right: MacVirtualKeyCode.ansiD.rawValue,
        lightPunch: MacVirtualKeyCode.ansiF.rawValue,
        heavyPunch: MacVirtualKeyCode.ansiG.rawValue,
        lightKick: MacVirtualKeyCode.ansiH.rawValue,
        heavyKick: MacVirtualKeyCode.ansiJ.rawValue
    )

    public static func playerTwo(layout: PlayerTwoKeyboardLayout) -> PlayerKeyBindings {
        let attacks: (UInt16, UInt16, UInt16, UInt16)
        switch layout {
        case .numpad:
            attacks = (
                MacVirtualKeyCode.keypad4.rawValue,
                MacVirtualKeyCode.keypad5.rawValue,
                MacVirtualKeyCode.keypad1.rawValue,
                MacVirtualKeyCode.keypad2.rawValue
            )
        case .alternate:
            attacks = (
                MacVirtualKeyCode.ansiI.rawValue,
                MacVirtualKeyCode.ansiO.rawValue,
                MacVirtualKeyCode.ansiK.rawValue,
                MacVirtualKeyCode.ansiL.rawValue
            )
        }
        return PlayerKeyBindings(
            up: MacVirtualKeyCode.upArrow.rawValue,
            down: MacVirtualKeyCode.downArrow.rawValue,
            left: MacVirtualKeyCode.leftArrow.rawValue,
            right: MacVirtualKeyCode.rightArrow.rawValue,
            lightPunch: attacks.0,
            heavyPunch: attacks.1,
            lightKick: attacks.2,
            heavyKick: attacks.3
        )
    }

    /// Face buttons map to LP/HP/LK/HK for any `GCController` extended profile.
    public static let gamepadFace: GamepadFaceMap = GamepadFaceMap(
        lightPunch: .buttonX,
        heavyPunch: .buttonY,
        lightKick: .buttonA,
        heavyKick: .buttonB
    )
}