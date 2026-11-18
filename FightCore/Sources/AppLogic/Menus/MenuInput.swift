/// Platform-free menu commands from keyboard, gamepad, or on-screen controls.
public enum MenuCommand: Sendable, Equatable, Hashable {
    case up
    case down
    case left
    case right
    case confirm
    case cancel
    case pause
}