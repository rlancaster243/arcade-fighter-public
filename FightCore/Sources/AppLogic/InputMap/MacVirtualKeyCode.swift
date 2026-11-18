/// macOS `NSEvent` / HIToolbox virtual key codes used by keyboard adapters.
///
/// Values match Apple’s `Events.h` (`kVK_*`). App adapters must use these symbols
/// rather than raw integers so `T-ADAPT-SCRIPT` can verify parity.
public enum MacVirtualKeyCode: UInt16, Sendable, Equatable, Hashable, Codable, CaseIterable {
    // MARK: - P1 movement (WASD)
    case ansiW = 0x0D
    case ansiA = 0x00
    case ansiS = 0x01
    case ansiD = 0x02

    // MARK: - P1 attacks (F/G/H/J)
    case ansiF = 0x03
    case ansiG = 0x05
    case ansiH = 0x04
    case ansiJ = 0x26

    // MARK: - P2 movement (arrows)
    case upArrow = 0x7E
    case downArrow = 0x7D
    case leftArrow = 0x7B
    case rightArrow = 0x7C

    // MARK: - P2 attacks — numpad (standard layout)
    case keypad4 = 0x56
    case keypad5 = 0x57
    case keypad1 = 0x53
    case keypad2 = 0x54

    // MARK: - P2 attacks — alternate (I/K/O/L on main keyboard)
    case ansiI = 0x22
    case ansiK = 0x28
    case ansiO = 0x1F
    case ansiL = 0x25
}

extension MacVirtualKeyCode {
    /// Human-readable label for key-test UI and remap screens.
    public var displayName: String {
        switch self {
        case .ansiW: "W"
        case .ansiA: "A"
        case .ansiS: "S"
        case .ansiD: "D"
        case .ansiF: "F"
        case .ansiG: "G"
        case .ansiH: "H"
        case .ansiJ: "J"
        case .upArrow: "↑"
        case .downArrow: "↓"
        case .leftArrow: "←"
        case .rightArrow: "→"
        case .keypad4: "Num 4"
        case .keypad5: "Num 5"
        case .keypad1: "Num 1"
        case .keypad2: "Num 2"
        case .ansiI: "I"
        case .ansiK: "K"
        case .ansiO: "O"
        case .ansiL: "L"
        }
    }
}