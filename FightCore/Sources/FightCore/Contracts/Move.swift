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

/// One active-frame hit of a multi-hit move. `activeFrame` is the index within the active window.
public struct MoveHit: Sendable, Equatable, Hashable, Codable {
    public var activeFrame: Int32
    public var damage: Int32
    public var hitstun: Int32
    public var blockstun: Int32
    public var hitstop: Int32

    public init(
        activeFrame: Int32,
        damage: Int32,
        hitstun: Int32,
        blockstun: Int32,
        hitstop: Int32
    ) {
        self.activeFrame = activeFrame
        self.damage = damage
        self.hitstun = hitstun
        self.blockstun = blockstun
        self.hitstop = hitstop
    }
}

/// Facing-right Q8 velocity for one `stateTick` of a move. `x` is mirrored when the fighter faces left.
/// `y` uses the same sign as jump velocity (negative is up).
public struct FrameVelocity: Sendable, Equatable, Hashable, Codable {
    public var x: Int32
    public var y: Int32

    public init(x: Int32, y: Int32) {
        self.x = x
        self.y = y
    }
}

/// Data for a move that spawns projectiles. Speed is a Q8 magnitude along facing (positive moves forward).
public struct ProjectileSpawn: Sendable, Equatable, Hashable, Codable {
    public var speed: Int32
    public var lifetime: Int32
    public var hitbox: Hitbox
    public var damage: Int32
    public var maxOnScreen: Int32
    public var spawnCount: Int32
    public var hitsAirborne: Bool

    public init(
        speed: Int32,
        lifetime: Int32,
        hitbox: Hitbox,
        damage: Int32,
        maxOnScreen: Int32,
        spawnCount: Int32,
        hitsAirborne: Bool
    ) {
        self.speed = speed
        self.lifetime = lifetime
        self.hitbox = hitbox
        self.damage = damage
        self.maxOnScreen = maxOnScreen
        self.spawnCount = spawnCount
        self.hitsAirborne = hitsAirborne
    }
}

/// Counter stance. A non-throw strike that connects while `stateTick` is in `[startTick, endTick)`
/// is negated and `followUpMoveID` is applied immediately as a hit. Throws ignore the window.
public struct CounterWindow: Sendable, Equatable, Hashable, Codable {
    public var startTick: Int32
    public var endTick: Int32
    public var followUpMoveID: String

    public init(startTick: Int32, endTick: Int32, followUpMoveID: String) {
        self.startTick = startTick
        self.endTick = endTick
        self.followUpMoveID = followUpMoveID
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
    /// Non-throw hits absorbed before this attack takes hitstun. Omitted data means 0.
    public var armorHits: Int32
    /// Present only when this move spawns projectiles.
    public var projectile: ProjectileSpawn?
    /// Per-tick Q8 displacement. Empty means the move does not add its own velocity.
    public var velocities: [FrameVelocity]
    /// `stateTick` values during which this move is invulnerable.
    public var invulnerableFrames: [Int32]
    /// Command-grab rule: the attack does not connect against `FighterStateKind.airborne`.
    public var whiffsVsAirborne: Bool
    public var counter: CounterWindow?
    /// When non-empty, only these active-frame indices connect, using their own damage and stun.
    public var hits: [MoveHit]

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
        unblockable: Bool = false,
        armorHits: Int32 = 0,
        projectile: ProjectileSpawn? = nil,
        velocities: [FrameVelocity] = [],
        invulnerableFrames: [Int32] = [],
        whiffsVsAirborne: Bool = false,
        counter: CounterWindow? = nil,
        hits: [MoveHit] = []
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
        self.armorHits = armorHits
        self.projectile = projectile
        self.velocities = velocities
        self.invulnerableFrames = invulnerableFrames
        self.whiffsVsAirborne = whiffsVsAirborne
        self.counter = counter
        self.hits = hits
    }
}
