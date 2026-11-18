extension MacVirtualKeyCode {
    public init?(rawKeyCode: UInt16) {
        if let match = MacVirtualKeyCode.allCases.first(where: { $0.rawValue == rawKeyCode }) {
            self = match
        } else {
            return nil
        }
    }

    public static func displayLabel(for keyCode: UInt16) -> String {
        if let known = MacVirtualKeyCode(rawKeyCode: keyCode) {
            return known.displayName
        }
        return String(format: "0x%02X", keyCode)
    }

    /// Expected HIToolbox `kVK_*` values (verified in `T-APPLOGIC-KEYMAP`).
    public static let hitoolboxExpectations: [(MacVirtualKeyCode, UInt16)] = [
        (.ansiA, 0x00), (.ansiS, 0x01), (.ansiD, 0x02), (.ansiF, 0x03), (.ansiH, 0x04),
        (.ansiG, 0x05), (.ansiW, 0x0D), (.ansiO, 0x1F), (.ansiI, 0x22), (.ansiL, 0x25),
        (.ansiJ, 0x26), (.ansiK, 0x28), (.keypad1, 0x53), (.keypad2, 0x54),
        (.keypad4, 0x56), (.keypad5, 0x57),
        (.leftArrow, 0x7B), (.rightArrow, 0x7C), (.downArrow, 0x7D), (.upArrow, 0x7E),
    ]
}