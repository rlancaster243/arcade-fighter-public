public enum FighterStateKind: UInt8, Sendable, Equatable, Hashable, Codable, CaseIterable {
    case idle = 0
    case walkForward
    case walkBack
    case crouch
    case jumpStartup
    case airborne
    case landing
    case attackStartup
    case attackActive
    case attackRecovery
    case hitstun
    case blockstunStand
    case blockstunCrouch
    case knockdown
    case getup
    case throwStartup
    case throwing
    case beingThrown
    case ko
    case win
}

public struct FighterState: Sendable, Equatable, Hashable, Codable {
    public var kind: FighterStateKind
    /// Elapsed ticks in current kind (sub-state timer).
    public var timer: Int32
    public var position: Vec2
    public var velocity: Vec2
    public var facingRight: Bool
    public var health: Int32
    public var meter: Int32
    public var activeMoveID: String
    public var stateTick: Int32

    public init(
        kind: FighterStateKind = .idle,
        timer: Int32 = 0,
        position: Vec2 = .zero,
        velocity: Vec2 = .zero,
        facingRight: Bool = true,
        health: Int32 = 1000,
        meter: Int32 = 0,
        activeMoveID: String = "",
        stateTick: Int32 = 0
    ) {
        self.kind = kind
        self.timer = timer
        self.position = position
        self.velocity = velocity
        self.facingRight = facingRight
        self.health = health
        self.meter = meter
        self.activeMoveID = activeMoveID
        self.stateTick = stateTick
    }
}