/// Per-match CPU parameters rolled from difficulty tier + match seed (deterministic).
public struct DifficultyProfile: Sendable, Equatable, Hashable, Codable {
    public var difficulty: Difficulty
    /// Ticks between AI re-evaluation windows.
    public var reactionDelayTicks: Int32
    /// 0–1000: probability the intended button is pressed as planned.
    public var inputAccuracyPermille: Int32
  /// 0–1000: relative weight for block intent when threatened / neutral defense.
    public var blockRatePermille: Int32
    /// 0–1000: relative weight for attempting a special motion sequence.
    public var specialRatePermille: Int32
    /// 0–1000: relative weight for attempting a super motion sequence.
    public var superRatePermille: Int32
    /// Mixed into per-epoch RNG streams for this controller.
    public var decisionSeed: UInt64

    public init(
        difficulty: Difficulty,
        reactionDelayTicks: Int32,
        inputAccuracyPermille: Int32,
        blockRatePermille: Int32,
        specialRatePermille: Int32,
        superRatePermille: Int32,
        decisionSeed: UInt64
    ) {
        self.difficulty = difficulty
        self.reactionDelayTicks = reactionDelayTicks
        self.inputAccuracyPermille = inputAccuracyPermille
        self.blockRatePermille = blockRatePermille
        self.specialRatePermille = specialRatePermille
        self.superRatePermille = superRatePermille
        self.decisionSeed = decisionSeed
    }

    private struct BaseTier: Sendable {
        var reactionMin: Int32
        var reactionMax: Int32
        var accuracy: Int32
        var block: Int32
        var special: Int32
        var superMove: Int32
    }

    private static func baseTier(_ difficulty: Difficulty) -> BaseTier {
        switch difficulty {
        case .easy:
            return BaseTier(reactionMin: 22, reactionMax: 36, accuracy: 620, block: 180, special: 70, superMove: 35)
        case .normal:
            return BaseTier(reactionMin: 12, reactionMax: 20, accuracy: 820, block: 420, special: 200, superMove: 110)
        case .hard:
            return BaseTier(reactionMin: 5, reactionMax: 11, accuracy: 960, block: 720, special: 380, superMove: 260)
        }
    }

    /// Rolls a profile for `difficulty` using `matchSeed` (stable across runs).
    public static func seeded(difficulty: Difficulty, matchSeed: UInt64) -> DifficultyProfile {
        var rng = SeededRNG(seed: matchSeed &+ UInt64(difficulty.rawValue) &* 0x9E37_79B9_7F4A_7C15)
        let base = baseTier(difficulty)
        let reactionSpan = max(0, base.reactionMax - base.reactionMin)
        let reactionDelay = base.reactionMin + Int32(rng.nextBounded(UInt64(reactionSpan + 1)))
        func jittered(_ center: Int32, spread: Int32) -> Int32 {
            let delta = Int32(rng.nextBounded(UInt64(spread &* 2 &+ 1))) - spread
            return clampPermille(center + delta)
        }
        return DifficultyProfile(
            difficulty: difficulty,
            reactionDelayTicks: max(4, reactionDelay),
            inputAccuracyPermille: jittered(base.accuracy, spread: 45),
            blockRatePermille: jittered(base.block, spread: 60),
            specialRatePermille: jittered(base.special, spread: 55),
            superRatePermille: jittered(base.superMove, spread: 40),
            decisionSeed: rng.next()
        )
    }

    private static func clampPermille(_ value: Int32) -> Int32 {
        if value < 0 { return 0 }
        if value > 1000 { return 1000 }
        return value
    }
}