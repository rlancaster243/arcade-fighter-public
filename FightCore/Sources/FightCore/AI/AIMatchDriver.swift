public struct AIMatchResult: Sendable, Equatable, Hashable, Codable {
    public var seed: UInt64
    public var ticksSimulated: Int32
    public var finalStateHash: UInt64
    public var p1Health: Int32
    public var p2Health: Int32
    public var p1RoundsWon: Int32
    public var p2RoundsWon: Int32
    public var winner: PlayerSlot?

    public init(
        seed: UInt64,
        ticksSimulated: Int32,
        finalStateHash: UInt64,
        p1Health: Int32,
        p2Health: Int32,
        p1RoundsWon: Int32,
        p2RoundsWon: Int32,
        winner: PlayerSlot?
    ) {
        self.seed = seed
        self.ticksSimulated = ticksSimulated
        self.finalStateHash = finalStateHash
        self.p1Health = p1Health
        self.p2Health = p2Health
        self.p1RoundsWon = p1RoundsWon
        self.p2RoundsWon = p2RoundsWon
        self.winner = winner
    }
}

public struct FightSimBatchConfig: Sendable, Equatable, Hashable, Codable {
    public var batchSeed: UInt64
    public var matchCount: Int32
    public var ticksPerMatch: Int32
    public var p1Difficulty: Difficulty
    public var p2Difficulty: Difficulty

    public init(
        batchSeed: UInt64,
        matchCount: Int32,
        ticksPerMatch: Int32,
        p1Difficulty: Difficulty,
        p2Difficulty: Difficulty
    ) {
        self.batchSeed = batchSeed
        self.matchCount = matchCount
        self.ticksPerMatch = ticksPerMatch
        self.p1Difficulty = p1Difficulty
        self.p2Difficulty = p2Difficulty
    }
}

public struct FightSimBatchReport: Sendable, Equatable, Hashable, Codable {
    public static let schemaVersion: Int32 = 1

    public var schemaVersion: Int32
    public var config: FightSimBatchConfig
    public var matches: [AIMatchResult]
    public var p1Wins: Int32
    public var p2Wins: Int32
    public var draws: Int32

    public init(config: FightSimBatchConfig, matches: [AIMatchResult]) {
        self.schemaVersion = Self.schemaVersion
        self.config = config
        self.matches = matches
        var p1 = Int32(0)
        var p2 = Int32(0)
        var draws = Int32(0)
        for m in matches {
            switch m.winner {
            case .p1: p1 &+= 1
            case .p2: p2 &+= 1
            case .none: draws &+= 1
            }
        }
        self.p1Wins = p1
        self.p2Wins = p2
        self.draws = draws
    }
}

public enum AIMatchDriver {
    public static func runMatch(
        matchSeed: UInt64,
        p1: DifficultyProfile,
        p2: DifficultyProfile,
        tickLimit: Int32
    ) -> (snapshot: GameSnapshot, result: AIMatchResult) {
        let ai1 = CPUAIController(profile: p1)
        let ai2 = CPUAIController(profile: p2)
        var sim = Simulation()
        var snap = SimulationBootstrap.greyboxMatch(seed: matchSeed)
        var ticks: Int32 = 0
        let limit = tickLimit > 0 ? tickLimit : MatchRules.roundTickLimit
        while ticks < limit, !snap.rules.matchOver {
            var rng = snap.rng
            let frames = [
                ai1.inputs(for: .p1, snapshot: snap, rng: &rng),
                ai2.inputs(for: .p2, snapshot: snap, rng: &rng),
            ]
            snap.rng = rng
            sim.step(inputs: frames, snapshot: &snap)
            ticks &+= 1
        }
        let winner: PlayerSlot? = {
            if snap.rules.winner != nil { return snap.rules.winner }
            let h1 = snap.fighters[0].health
            let h2 = snap.fighters[1].health
            if h1 > h2 { return .p1 }
            if h2 > h1 { return .p2 }
            return nil
        }()
        let result = AIMatchResult(
            seed: matchSeed,
            ticksSimulated: ticks,
            finalStateHash: snap.stateHash(),
            p1Health: snap.fighters[0].health,
            p2Health: snap.fighters[1].health,
            p1RoundsWon: snap.rules.p1RoundsWon,
            p2RoundsWon: snap.rules.p2RoundsWon,
            winner: winner
        )
        return (snap, result)
    }

    public static func runBatch(_ config: FightSimBatchConfig) -> FightSimBatchReport {
        var results: [AIMatchResult] = []
        results.reserveCapacity(Int(config.matchCount))
        for i in Int32(0)..<config.matchCount {
            let matchSeed = config.batchSeed &+ UInt64(i) &* 0xD1E2_3F45_6789_ABCD
            let p1 = DifficultyProfile.seeded(difficulty: config.p1Difficulty, matchSeed: matchSeed ^ 0x1111)
            let p2 = DifficultyProfile.seeded(difficulty: config.p2Difficulty, matchSeed: matchSeed ^ 0x2222)
            let (_, result) = runMatch(matchSeed: matchSeed, p1: p1, p2: p2, tickLimit: config.ticksPerMatch)
            results.append(result)
        }
        return FightSimBatchReport(config: config, matches: results)
    }
}