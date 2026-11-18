/// Platform-free menu key routing (macOS virtual key codes from Carbon/HIToolbox).
public enum MenuKeyboardMode: Equatable, Sendable {
    /// Menu first responder: navigation + confirm + pause/cancel.
    case fullNavigation
    /// During an active round: only P / Esc; navigation must not steal fight input.
    case matchPauseHotkeysOnly
}

public enum MenuKeyboardKeyCode {
    public static let escape: UInt16 = 53
    public static let pauseP: UInt16 = 35
    public static let returnKey: UInt16 = 36
    public static let space: UInt16 = 49
    public static let upArrow: UInt16 = 126
    public static let downArrow: UInt16 = 125
    public static let leftArrow: UInt16 = 123
    public static let rightArrow: UInt16 = 124
    public static let ansiW: UInt16 = 13
    public static let ansiS: UInt16 = 1
    public static let ansiA: UInt16 = 0
    public static let ansiD: UInt16 = 2
}

public enum MenuKeyboardRouting {
    public static func menuCommand(keyCode: UInt16, mode: MenuKeyboardMode) -> MenuCommand? {
        switch mode {
        case .matchPauseHotkeysOnly:
            return matchPauseHotkeyCommand(keyCode: keyCode)
        case .fullNavigation:
            return fullNavigationCommand(keyCode: keyCode)
        }
    }

    public static func matchPauseHotkeyCommand(keyCode: UInt16) -> MenuCommand? {
        switch keyCode {
        case MenuKeyboardKeyCode.escape:
            return .cancel
        case MenuKeyboardKeyCode.pauseP:
            return .pause
        default:
            return nil
        }
    }

    public static func fullNavigationCommand(keyCode: UInt16) -> MenuCommand? {
        switch keyCode {
        case MenuKeyboardKeyCode.upArrow, MenuKeyboardKeyCode.ansiW:
            return .up
        case MenuKeyboardKeyCode.downArrow, MenuKeyboardKeyCode.ansiS:
            return .down
        case MenuKeyboardKeyCode.leftArrow, MenuKeyboardKeyCode.ansiA:
            return .left
        case MenuKeyboardKeyCode.rightArrow, MenuKeyboardKeyCode.ansiD:
            return .right
        case MenuKeyboardKeyCode.returnKey, MenuKeyboardKeyCode.space:
            return .confirm
        case MenuKeyboardKeyCode.escape:
            return .cancel
        case MenuKeyboardKeyCode.pauseP:
            return .pause
        default:
            return nil
        }
    }
}