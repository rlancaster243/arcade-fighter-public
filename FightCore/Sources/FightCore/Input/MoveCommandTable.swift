/// One way to start `moveID` for `fighterID`. `buttons` is the mask that must be held.
/// A punch-class or kick-class move is two rows with the same move id.
public struct MoveCommand: Sendable, Equatable {
    public var fighterID: String
    public var moveID: String
    public var motion: MotionPattern?
    public var buttons: UInt8

    public init(fighterID: String, moveID: String, motion: MotionPattern?, buttons: UInt8) {
        self.fighterID = fighterID
        self.moveID = moveID
        self.motion = motion
        self.buttons = buttons
    }
}

public struct MoveCommandTable: Sendable, Equatable {
    public var commands: [MoveCommand]

    public init(commands: [MoveCommand] = []) {
        self.commands = commands
    }

    /// Highest-priority move for this resolved input. Nil when nothing matches.
    public func moveID(fighterID: String, resolved: ResolvedInput) -> String? {
        let pressed = resolved.buttons & Self.attackMask
        guard pressed != 0 else { return nil }
        let mine = commands.filter { $0.fighterID == fighterID }
        if let motion = resolved.motion {
            let hits = mine.filter { command in
                command.motion == motion
                    && command.buttons != 0
                    && (pressed & command.buttons) == command.buttons
            }
            if let exact = hits.first(where: { $0.buttons == pressed }) {
                return exact.moveID
            }
            return hits.first?.moveID
        }
        let throwMask = Self.bit(.lightPunch) | Self.bit(.lightKick)
        if pressed == throwMask {
            return mine.first { $0.motion == nil && $0.buttons == throwMask }?.moveID
        }
        guard Self.popcount(pressed) == 1 else { return nil }
        return mine.first { $0.motion == nil && $0.buttons == pressed }?.moveID
    }

    public static func bit(_ button: Button) -> UInt8 {
        1 << button.rawValue
    }

    private static let attackMask: UInt8 = 0b0000_1111

    private static func popcount(_ bits: UInt8) -> Int {
        var value = bits
        var count = 0
        while value != 0 {
            count += Int(value & 1)
            value >>= 1
        }
        return count
    }
}
