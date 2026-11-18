public enum MoveInputKind: UInt8, Sendable, Equatable, Hashable, Codable {
    case normal = 0
    case special
    case superMove
    case throwMove
}

public struct MoveFrameBoxes: Sendable, Equatable, Hashable, Codable {
    public var hit: [Hitbox]
    public var hurt: [Hitbox]
    public var push: [Hitbox]
    public var throwBoxes: [Hitbox]

    public init(
        hit: [Hitbox] = [],
        hurt: [Hitbox] = [],
        push: [Hitbox] = [],
        throwBoxes: [Hitbox] = []
    ) {
        self.hit = hit
        self.hurt = hurt
        self.push = push
        self.throwBoxes = throwBoxes
    }
}

public struct MoveDef: Sendable, Equatable, Hashable, Codable {
    public var id: String
    public var name: String
    public var inputKind: MoveInputKind
    public var startup: Int32
    public var active: Int32
    public var recovery: Int32
    public var frames: MoveFrameBoxes
    public var damage: Int32
    public var chip: Int32
    public var hitstun: Int32
    public var blockstun: Int32
    public var pushbackHit: Int32
    public var pushbackBlock: Int32
    public var meterGain: Int32
    public var hitstop: Int32
    public var guardLevel: GuardLevel
    public var unblockable: Bool

    public init(
        id: String,
        name: String,
        inputKind: MoveInputKind = .normal,
        startup: Int32 = 0,
        active: Int32 = 0,
        recovery: Int32 = 0,
        frames: MoveFrameBoxes = MoveFrameBoxes(),
        damage: Int32 = 0,
        chip: Int32 = 0,
        hitstun: Int32 = 0,
        blockstun: Int32 = 0,
        pushbackHit: Int32 = 0,
        pushbackBlock: Int32 = 0,
        meterGain: Int32 = 0,
        hitstop: Int32 = 0,
        guardLevel: GuardLevel = .mid,
        unblockable: Bool = false
    ) {
        self.id = id
        self.name = name
        self.inputKind = inputKind
        self.startup = startup
        self.active = active
        self.recovery = recovery
        self.frames = frames
        self.damage = damage
        self.chip = chip
        self.hitstun = hitstun
        self.blockstun = blockstun
        self.pushbackHit = pushbackHit
        self.pushbackBlock = pushbackBlock
        self.meterGain = meterGain
        self.hitstop = hitstop
        self.guardLevel = guardLevel
        self.unblockable = unblockable
    }
}