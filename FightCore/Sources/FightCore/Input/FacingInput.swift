/// Screen → fighter-relative numpad (2 = down; 6 = toward opponent).
public enum FacingInput: Sendable {
    public static func logicalNumpad(from direction: Direction, facingRight: Bool) -> UInt8 {
        let screen = numpad(from: direction)
        guard screen != 0 else { return 0 }
        return facingRight ? screen : mirrorNumpad(screen)
    }

    public static func numpad(from direction: Direction) -> UInt8 {
        switch direction {
        case .neutral: 0
        case .downLeft: 1
        case .down: 2
        case .downRight: 3
        case .left: 4
        case .right: 6
        case .upLeft: 7
        case .up: 8
        case .upRight: 9
        }
    }

    public static func mirrorNumpad(_ n: UInt8) -> UInt8 {
        switch n {
        case 1: 3
        case 3: 1
        case 4: 6
        case 6: 4
        case 7: 9
        case 9: 7
        default: n
        }
    }
}