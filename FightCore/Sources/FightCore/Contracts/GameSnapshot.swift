public struct GameSnapshot: Sendable, Equatable, Hashable, Codable {
    public var tick: Int32
    public var rng: SeededRNG
    public var fighters: [FighterState]
    public var projectiles: [Projectile]
    public var rules: MatchRules
    public var events: [GameEvent]
    public var fighterIDs: [String]

    public init(
        tick: Int32 = 0,
        rng: SeededRNG = SeededRNG(seed: 1),
        fighters: [FighterState] = [],
        projectiles: [Projectile] = [],
        rules: MatchRules = MatchRules(),
        events: [GameEvent] = [],
        fighterIDs: [String] = []
    ) {
        self.tick = tick
        self.rng = rng
        self.fighters = fighters
        self.projectiles = projectiles
        self.rules = rules
        self.events = events
        self.fighterIDs = fighterIDs
    }
}