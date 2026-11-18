public enum GameEventKind: UInt8, Sendable, Equatable, Hashable, Codable {
    case none = 0
    case hit
    case block
    case chip
    case throwHit
    case knockdown
    case roundStart
    case roundEnd
    case matchWin
    case timeOver
    case whiff
}

public struct GameEvent: Sendable, Equatable, Hashable, Codable {
    public var kind: GameEventKind
    public var tick: Int32
    public var attacker: PlayerSlot
    public var defender: PlayerSlot
    public var moveID: String
    public var damage: Int32

    public init(
        kind: GameEventKind = .none,
        tick: Int32 = 0,
        attacker: PlayerSlot = .p1,
        defender: PlayerSlot = .p2,
        moveID: String = "",
        damage: Int32 = 0
    ) {
        self.kind = kind
        self.tick = tick
        self.attacker = attacker
        self.defender = defender
        self.moveID = moveID
        self.damage = damage
    }
}