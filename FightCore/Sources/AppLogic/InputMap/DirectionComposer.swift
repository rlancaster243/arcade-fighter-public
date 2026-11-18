import FightCore

/// Combines orthogonal direction holds into an 8-way `Direction` (numpad notation).
public enum DirectionComposer {
    public static func compose(up: Bool, down: Bool, left: Bool, right: Bool) -> Direction {
        if down, left { return .downLeft }
        if down, right { return .downRight }
        if up, left { return .upLeft }
        if up, right { return .upRight }
        if down { return .down }
        if up { return .up }
        if left { return .left }
        if right { return .right }
        return .neutral
    }
}