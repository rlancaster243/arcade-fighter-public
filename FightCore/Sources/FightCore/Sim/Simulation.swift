/// Fixed 60 Hz simulation orchestrator (one `step` per tick).
public struct Simulation: Sendable {
    public var motion: MotionParsing
    public var fighterStep: FighterStepping
    public var collision: CollisionResolving
    public var matchDirect: MatchDirecting

    public init(
        motion: MotionParsing = MotionParsingStub(),
        fighterStep: FighterStepping = FighterSteppingStub(),
        collision: CollisionResolving = CollisionResolvingStub(),
        matchDirect: MatchDirecting = MatchDirectingStub()
    ) {
        self.motion = motion
        self.fighterStep = fighterStep
        self.collision = collision
        self.matchDirect = matchDirect
    }

    public mutating func step(inputs: [InputFrame], snapshot: inout GameSnapshot) {
        snapshot.events.removeAll(keepingCapacity: true)
        motion.apply(inputs: inputs, to: &snapshot)
        fighterStep.stepFighters(snapshot: &snapshot)
        collision.resolveMovement(snapshot: &snapshot)
        collision.resolveHits(snapshot: &snapshot)
        matchDirect.applyRules(snapshot: &snapshot)
    }
}

public enum SimulationBootstrap {
    public static func greyboxMatch(seed: UInt64 = 0xC0FFEE) -> GameSnapshot {
        let p1 = FighterState(
            position: Vec2(x: Fixed(pixels: -80), y: .zero),
            facingRight: true,
            health: 1000
        )
        let p2 = FighterState(
            position: Vec2(x: Fixed(pixels: 80), y: .zero),
            facingRight: false,
            health: 1000
        )
        return GameSnapshot(
            tick: 0,
            rng: SeededRNG(seed: seed),
            fighters: [p1, p2],
            projectiles: [],
            rules: MatchRules(),
            events: [],
            fighterIDs: ["greybox", "greybox"]
        )
    }
}