public struct HurtboxSet: Sendable, Equatable, Hashable, Codable {
    public var state: FighterStateKind
    public var boxes: [Hitbox]
}

public struct FighterDef: Sendable, Equatable, Hashable, Codable {
    public var schemaVersion: Int32
    public var id: String
    public var displayName: String
    public var archetype: String
    public var gamePlan: String
    public var health: Int32
    public var walkForward: Int32
    public var walkBack: Int32
    public var jumpVelocityY: Int32
    public var gravity: Int32
    public var pushbox: Hitbox
    public var hurtboxes: [HurtboxSet]
    public var spriteSheetPath: String
    public var moves: [MoveDef]

    public init(
        schemaVersion: Int32 = 1,
        id: String,
        displayName: String,
        archetype: String = "balanced",
        gamePlan: String,
        health: Int32 = 1000,
        walkForward: Int32 = 3,
        walkBack: Int32 = 2,
        jumpVelocityY: Int32 = -14 * Fixed.scale,
        gravity: Int32 = 1,
        pushbox: Hitbox = Hitbox(x: -20, y: -90, w: 40, h: 90),
        hurtboxes: [HurtboxSet] = [],
        spriteSheetPath: String = "",
        moves: [MoveDef] = []
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.displayName = displayName
        self.archetype = archetype
        self.gamePlan = gamePlan
        self.health = health
        self.walkForward = walkForward
        self.walkBack = walkBack
        self.jumpVelocityY = jumpVelocityY
        self.gravity = gravity
        self.pushbox = pushbox
        self.hurtboxes = hurtboxes
        self.spriteSheetPath = spriteSheetPath
        self.moves = moves
    }
}