import Foundation

/// Headless CPU-vs-CPU on shipped fighter data. Observes snapshots the existing
/// `Simulation.step` already produces; it does not change step behaviour.
public enum RosterMatchDriver {
    public struct Config: Sendable, Equatable {
        public var p1FighterID: String
        public var p2FighterID: String
        public var stageID: String
        public var seedStart: UInt64
        public var seedEnd: UInt64
        public var p1Difficulty: Difficulty
        public var p2Difficulty: Difficulty
        /// Safety cap. A match also stops when `MatchRules.matchOver` becomes true.
        public var tickLimit: Int32

        public init(
            p1FighterID: String,
            p2FighterID: String,
            stageID: String = "stage1",
            seedStart: UInt64,
            seedEnd: UInt64,
            p1Difficulty: Difficulty = .hard,
            p2Difficulty: Difficulty = .hard,
            tickLimit: Int32 = MatchRules.roundTickLimit * MatchRules.maxRounds * 2
        ) {
            self.p1FighterID = p1FighterID
            self.p2FighterID = p2FighterID
            self.stageID = stageID
            self.seedStart = seedStart
            self.seedEnd = seedEnd
            self.p1Difficulty = p1Difficulty
            self.p2Difficulty = p2Difficulty
            self.tickLimit = tickLimit
        }
    }

    public static func run(_ config: Config, fromFile file: String = #filePath) throws -> RosterSimReport {
        guard config.seedEnd >= config.seedStart else {
            throw RosterMatchError.seedRange(config.seedStart, config.seedEnd)
        }
        guard config.tickLimit > 0 else {
            throw RosterMatchError.tickLimit(config.tickLimit)
        }
        let loaded = try loadStack(config: config, fromFile: file)
        var matches: [RosterSimMatch] = []
        let count = config.seedEnd - config.seedStart + 1
        matches.reserveCapacity(Int(count))
        var seed = config.seedStart
        while seed <= config.seedEnd {
            matches.append(runOne(seed: seed, config: config, loaded: loaded))
            if seed == UInt64.max { break }
            seed += 1
        }
        return RosterSimReport(config: config, stageID: config.stageID, matches: matches)
    }

    private struct LoadedStack {
        var p1: FighterDef
        var p2: FighterDef
        var commands: [MoveCommand]
        var playLeftPx: Int32
        var playRightPx: Int32
    }

    private static func loadStack(config: Config, fromFile file: String) throws -> LoadedStack {
        let p1Dir = ContentPaths.fighterDirectory(config.p1FighterID, fromFile: file)
        let p2Dir = ContentPaths.fighterDirectory(config.p2FighterID, fromFile: file)
        let p1: FighterDef
        let p2: FighterDef
        do {
            p1 = try FighterLoader.loadFighter(from: p1Dir)
            p2 = try FighterLoader.loadFighter(from: p2Dir)
        } catch {
            throw RosterMatchError.loadFailed(String(describing: error))
        }
        guard p1.id == config.p1FighterID, p2.id == config.p2FighterID else {
            throw RosterMatchError.loadFailed(
                "fighter id mismatch: \(p1.id), \(p2.id)"
            )
        }
        let bounds: (playLeftPx: Int32, playRightPx: Int32)
        do {
            bounds = try StageBoundsLoader.playBounds(stageId: config.stageID, fromFile: file)
        } catch {
            throw RosterMatchError.loadFailed(String(describing: error))
        }
        let commands = try RosterCommandTable.commands(forFighterIDs: [p1.id, p2.id], fromFile: file)
        return LoadedStack(
            p1: p1,
            p2: p2,
            commands: commands,
            playLeftPx: bounds.playLeftPx,
            playRightPx: bounds.playRightPx
        )
    }

    private static func makeSimulation(_ loaded: LoadedStack) -> Simulation {
        var definitions: [String: FighterDef] = [:]
        definitions[loaded.p1.id] = loaded.p1
        definitions[loaded.p2.id] = loaded.p2
        let defs = [loaded.p1, loaded.p2]
        let context = CollisionMatchContext(
            fighterDefs: defs,
            playLeftPx: loaded.playLeftPx,
            playRightPx: loaded.playRightPx
        )
        return Simulation(
            motion: MotionParser(commands: MoveCommandTable(commands: loaded.commands)),
            fighterStep: FighterStepper(definitions: definitions),
            collision: CollisionResolver(context: context),
            matchDirect: MatchDirector(metadata: MatchMoveMetadataResolver(fighterDefs: defs))
        )
    }

    private static func initialSnapshot(seed: UInt64, loaded: LoadedStack) -> GameSnapshot {
        var snap = SimulationBootstrap.greyboxMatch(seed: seed)
        snap.fighterIDs = [loaded.p1.id, loaded.p2.id]
        snap.fighterStartHealth = [loaded.p1.health, loaded.p2.health]
        snap.fighters[0].health = loaded.p1.health
        snap.fighters[1].health = loaded.p2.health
        return snap
    }

    private static func runOne(seed: UInt64, config: Config, loaded: LoadedStack) -> RosterSimMatch {
        let profile1 = DifficultyProfile.seeded(difficulty: config.p1Difficulty, matchSeed: seed ^ 0x1111)
        let profile2 = DifficultyProfile.seeded(difficulty: config.p2Difficulty, matchSeed: seed ^ 0x2222)
        let ai1 = CPUAIController(profile: profile1)
        let ai2 = CPUAIController(profile: profile2)
        var sim = makeSimulation(loaded)
        var snap = initialSnapshot(seed: seed, loaded: loaded)
        var ticks: Int32 = 0
        var p1Throws: Int32 = 0
        var p2Throws: Int32 = 0
        var distanceRawSum: Int64 = 0
        var distanceSamples: Int32 = 0
        while ticks < config.tickLimit, !snap.rules.matchOver {
            sampleDistance(snap, rawSum: &distanceRawSum, samples: &distanceSamples)
            var rng = snap.rng
            let frames = [
                ai1.inputs(for: .p1, snapshot: snap, rng: &rng),
                ai2.inputs(for: .p2, snapshot: snap, rng: &rng),
            ]
            snap.rng = rng
            sim.step(inputs: frames, snapshot: &snap)
            for event in snap.events where event.kind == .throwHit {
                switch event.attacker {
                case .p1: p1Throws &+= 1
                case .p2: p2Throws &+= 1
                }
            }
            ticks &+= 1
        }
        let winner = decidedWinner(snap)
        return RosterSimMatch(
            seed: seed,
            ticksSimulated: ticks,
            finalStateHash: snap.stateHash(),
            matchCompleted: snap.rules.matchOver,
            winner: winnerName(winner),
            p1Health: snap.fighters[0].health,
            p2Health: snap.fighters[1].health,
            p1RoundsWon: snap.rules.p1RoundsWon,
            p2RoundsWon: snap.rules.p2RoundsWon,
            p1Throws: p1Throws,
            p2Throws: p2Throws,
            engagementDistanceRawSum: distanceRawSum,
            engagementSamples: distanceSamples
        )
    }

    /// Mean horizontal separation while both fighters are alive and the round is still going.
    private static func sampleDistance(
        _ snap: GameSnapshot,
        rawSum: inout Int64,
        samples: inout Int32
    ) {
        guard snap.fighters.count >= 2 else { return }
        guard !snap.rules.roundOver, !snap.rules.matchOver else { return }
        guard snap.fighters[0].health > 0, snap.fighters[1].health > 0 else { return }
        let dx = Int64(snap.fighters[0].position.x.raw) - Int64(snap.fighters[1].position.x.raw)
        rawSum += dx < 0 ? -dx : dx
        samples &+= 1
    }

    private static func decidedWinner(_ snap: GameSnapshot) -> PlayerSlot? {
        if snap.rules.winner != nil { return snap.rules.winner }
        guard snap.fighters.count >= 2 else { return nil }
        let h1 = snap.fighters[0].health
        let h2 = snap.fighters[1].health
        if h1 > h2 { return .p1 }
        if h2 > h1 { return .p2 }
        return nil
    }

    private static func winnerName(_ slot: PlayerSlot?) -> String? {
        switch slot {
        case .p1:
            return "p1"
        case .p2:
            return "p2"
        case nil:
            return nil
        }
    }
}

public enum RosterMatchError: Error, Equatable, CustomStringConvertible {
    case seedRange(UInt64, UInt64)
    case tickLimit(Int32)
    case loadFailed(String)
    case commandFailed(String)

    public var description: String {
        switch self {
        case .seedRange(let start, let end):
            return "seed range \(start)...\(end) is empty"
        case .tickLimit(let limit):
            return "tick limit \(limit) must be positive"
        case .loadFailed(let message):
            return message
        case .commandFailed(let message):
            return message
        }
    }
}

/// Builds the same motion rows the playable command loader builds, from `fighter.json`.
public enum RosterCommandTable {
    public static func commands(forFighterIDs ids: [String], fromFile file: String = #filePath) throws -> [MoveCommand] {
        var rows: [MoveCommand] = []
        var seen = Set<String>()
        for id in ids where seen.insert(id).inserted {
            let url = ContentPaths.fighterDirectory(id, fromFile: file).appendingPathComponent("fighter.json")
            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                throw RosterMatchError.commandFailed("could not read commands for \(id)")
            }
            let fileJSON: FighterJSON
            do {
                fileJSON = try JSONDecoder().decode(FighterJSON.self, from: data)
            } catch {
                throw RosterMatchError.commandFailed("could not decode commands for \(id): \(error)")
            }
            rows.append(contentsOf: try commands(fighterID: fileJSON.id, moves: fileJSON.moves))
        }
        return rows
    }

    static func commands(fighterID: String, moves: [FighterJSON.MoveJSON]) throws -> [MoveCommand] {
        var rows: [MoveCommand] = []
        for move in moves {
            let motion = try motionPattern(move)
            let masks = try buttonMasks(move)
            for mask in masks {
                rows.append(MoveCommand(fighterID: fighterID, moveID: move.id, motion: motion, buttons: mask))
            }
        }
        return rows
    }

    private static func motionPattern(_ move: FighterJSON.MoveJSON) throws -> MotionPattern? {
        if move.input.stance == "throw" { return nil }
        guard let raw = move.input.motion else { return nil }
        switch raw {
        case "236":
            return .qcf236
        case "214":
            return .qcb214
        case "623":
            return .dp623
        case "236236":
            return .super236236
        default:
            throw RosterMatchError.commandFailed("\(move.id) has unknown motion \(raw)")
        }
    }

    private static func buttonMasks(_ move: FighterJSON.MoveJSON) throws -> [UInt8] {
        if move.input.stance == "throw" {
            return [MoveCommandTable.bit(.lightPunch) | MoveCommandTable.bit(.lightKick)]
        }
        guard let button = move.input.button else { return [] }
        switch button {
        case "LP":
            return [MoveCommandTable.bit(.lightPunch)]
        case "HP":
            return [MoveCommandTable.bit(.heavyPunch)]
        case "LK":
            return [MoveCommandTable.bit(.lightKick)]
        case "HK":
            return [MoveCommandTable.bit(.heavyKick)]
        case "P":
            return [MoveCommandTable.bit(.lightPunch), MoveCommandTable.bit(.heavyPunch)]
        case "K":
            return [MoveCommandTable.bit(.lightKick), MoveCommandTable.bit(.heavyKick)]
        case "LP+LK":
            return [MoveCommandTable.bit(.lightPunch) | MoveCommandTable.bit(.lightKick)]
        default:
            throw RosterMatchError.commandFailed("\(move.id) has unknown button \(button)")
        }
    }
}

public struct RosterSimMatch: Sendable, Equatable, Codable {
    public var seed: UInt64
    public var ticksSimulated: Int32
    public var finalStateHash: UInt64
    public var matchCompleted: Bool
    /// "p1", "p2", or null when health and rounds are level.
    public var winner: String?
    public var p1Health: Int32
    public var p2Health: Int32
    public var p1RoundsWon: Int32
    public var p2RoundsWon: Int32
    public var p1Throws: Int32
    public var p2Throws: Int32
    /// Sum of absolute horizontal separation in Q8 raw units (256 = 1 px).
    public var engagementDistanceRawSum: Int64
    public var engagementSamples: Int32
}

public struct RosterSimReport: Sendable, Equatable, Codable {
    public static let schemaVersion: Int32 = 1

    public var schemaVersion: Int32
    public var p1FighterID: String
    public var p2FighterID: String
    public var stageID: String
    public var p1Difficulty: String
    public var p2Difficulty: String
    public var seedStart: UInt64
    public var seedEnd: UInt64
    public var tickLimit: Int32
    public var matches: [RosterSimMatch]
    public var p1Wins: Int32
    public var p2Wins: Int32
    public var draws: Int32
    public var p1ThrowCount: Int32
    public var p2ThrowCount: Int32
    public var engagementDistanceRawSum: Int64
    public var engagementSamples: Int32

    public init(config: RosterMatchDriver.Config, stageID: String, matches: [RosterSimMatch]) {
        schemaVersion = Self.schemaVersion
        p1FighterID = config.p1FighterID
        p2FighterID = config.p2FighterID
        self.stageID = stageID
        p1Difficulty = Self.difficultyName(config.p1Difficulty)
        p2Difficulty = Self.difficultyName(config.p2Difficulty)
        seedStart = config.seedStart
        seedEnd = config.seedEnd
        tickLimit = config.tickLimit
        self.matches = matches
        var p1Wins: Int32 = 0
        var p2Wins: Int32 = 0
        var draws: Int32 = 0
        var p1Throws: Int32 = 0
        var p2Throws: Int32 = 0
        var rawSum: Int64 = 0
        var samples: Int32 = 0
        for match in matches {
            switch match.winner {
            case "p1":
                p1Wins &+= 1
            case "p2":
                p2Wins &+= 1
            default:
                draws &+= 1
            }
            p1Throws &+= match.p1Throws
            p2Throws &+= match.p2Throws
            rawSum += match.engagementDistanceRawSum
            samples &+= match.engagementSamples
        }
        self.p1Wins = p1Wins
        self.p2Wins = p2Wins
        self.draws = draws
        p1ThrowCount = p1Throws
        p2ThrowCount = p2Throws
        engagementDistanceRawSum = rawSum
        engagementSamples = samples
    }

    public var meanEngagementDistancePx: Double {
        guard engagementSamples > 0 else { return 0 }
        return Double(engagementDistanceRawSum) / Double(engagementSamples) / Double(Fixed.scale)
    }

    private static func difficultyName(_ difficulty: Difficulty) -> String {
        switch difficulty {
        case .easy:
            return "easy"
        case .normal:
            return "normal"
        case .hard:
            return "hard"
        }
    }
}
