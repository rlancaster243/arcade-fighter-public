public struct Projectile: Sendable, Equatable, Hashable, Codable {
    public var id: UInt32
    public var owner: PlayerSlot
    public var position: Vec2
    public var velocity: Vec2
    public var hitbox: Hitbox
    public var damage: Int32
    public var lifetimeTicks: Int32
    public var active: Bool
    /// When false, the projectile does not connect with an `airborne` defender.
    public var hitsAirborne: Bool

    public init(
        id: UInt32,
        owner: PlayerSlot,
        position: Vec2,
        velocity: Vec2,
        hitbox: Hitbox,
        damage: Int32,
        lifetimeTicks: Int32,
        active: Bool = true,
        hitsAirborne: Bool = true
    ) {
        self.id = id
        self.owner = owner
        self.position = position
        self.velocity = velocity
        self.hitbox = hitbox
        self.damage = damage
        self.lifetimeTicks = lifetimeTicks
        self.active = active
        self.hitsAirborne = hitsAirborne
    }
}