import AppLogic
import Foundation
import FightCore

/// Wires shipped fighter defs and stage play bounds into the full simulation stack for integration runs.
enum IntegrationMatchHarness {
    static let shippedFighterIDs = ["greybox", "kestrel", "bruno", "ilse", "rook"]
    static let shippedStageIDs = StageBoundsLoader.shippedStageIDs
    /// Scripted input steps (pre-tick hashes); total hashes = this + 1 final snapshot.
    static let scriptedInputTickCount = 5

    static func loadFighter(_ id: String, fromFile file: String = #filePath) throws -> FighterDef {
        try FighterLoader.loadFighter(from: ContentPaths.fighterDirectory(id, fromFile: file))
    }

    static func loadFighters(_ ids: [String], fromFile file: String = #filePath) throws -> (FighterDef, FighterDef) {
        guard ids.count >= 2 else {
            throw HarnessError.needTwoFighters(ids)
        }
        return (
            try loadFighter(ids[0], fromFile: file),
            try loadFighter(ids[1], fromFile: file)
        )
    }

    static func playBounds(stageId: String, fromFile file: String = #filePath) throws -> (playLeftPx: Int32, playRightPx: Int32) {
        try StageBoundsLoader.playBounds(stageId: stageId, fromFile: file)
    }

    static func simulation(
        p1: FighterDef,
        p2: FighterDef,
        stageId: String,
        fromFile file: String = #filePath
    ) throws -> Simulation {
        try MatchSimulationFactory.make(
            p1PickID: p1.id,
            p1: p1,
            p2PickID: p2.id,
            p2: p2,
            stageId: stageId,
            fromFile: file
        ).simulation
    }

    static func snapshot(seed: UInt64, p1: FighterDef, p2: FighterDef) -> GameSnapshot {
        MatchSimulationFactory.matchSnapshot(seed: seed, p1: p1, p2: p2, fighterIDs: [p1.id, p2.id])
    }

    static func step(
        simulation: inout Simulation,
        snapshot: inout GameSnapshot,
        inputs: [InputFrame]
    ) {
        simulation.step(inputs: inputs, snapshot: &snapshot)
    }

    static func runReplay(
        _ fixture: ReplayFixture,
        stageId: String,
        fromFile file: String = #filePath,
        maxTicks: Int = 600
    ) throws -> [UInt64] {
        let (p1, p2) = try loadFighters(fixture.fighters, fromFile: file)
        var sim = try simulation(p1: p1, p2: p2, stageId: stageId, fromFile: file)
        var snap = snapshot(seed: fixture.seed, p1: p1, p2: p2)
        var hashes: [UInt64] = []
        let limit = min(fixture.inputs.count, maxTicks)
        hashes.reserveCapacity(limit + 1)
        for i in 0..<limit {
            hashes.append(snap.stateHash())
            let frames = fixture.inputFrames(at: i)
            step(simulation: &sim, snapshot: &snap, inputs: frames)
        }
        hashes.append(snap.stateHash())
        return hashes
    }

    static func runCPUVsCPU(
        matchSeed: UInt64,
        p1: FighterDef,
        p2: FighterDef,
        stageId: String,
        p1Difficulty: Difficulty,
        p2Difficulty: Difficulty,
        tickLimit: Int32,
        fromFile file: String = #filePath
    ) throws -> (snapshot: GameSnapshot, ticks: Int32, tickHashes: [UInt64]) {
        let profile1 = DifficultyProfile.seeded(difficulty: p1Difficulty, matchSeed: matchSeed ^ 0x1111)
        let profile2 = DifficultyProfile.seeded(difficulty: p2Difficulty, matchSeed: matchSeed ^ 0x2222)
        let ai1 = CPUAIController(profile: profile1)
        let ai2 = CPUAIController(profile: profile2)
        var sim = try simulation(p1: p1, p2: p2, stageId: stageId, fromFile: file)
        var snap = snapshot(seed: matchSeed, p1: p1, p2: p2)
        var hashes: [UInt64] = []
        hashes.reserveCapacity(Int(tickLimit) + 1)
        var ticks: Int32 = 0
        let limit = tickLimit > 0 ? tickLimit : MatchRules.roundTickLimit
        while ticks < limit, !snap.rules.matchOver {
            hashes.append(snap.stateHash())
            var rng = snap.rng
            let frames = [
                ai1.inputs(for: .p1, snapshot: snap, rng: &rng),
                ai2.inputs(for: .p2, snapshot: snap, rng: &rng),
            ]
            snap.rng = rng
            step(simulation: &sim, snapshot: &snap, inputs: frames)
            ticks &+= 1
        }
        hashes.append(snap.stateHash())
        return (snap, ticks, hashes)
    }

    static func scriptedTickCount(for scenarioID: String) -> Int {
        if let script = KitScripts.script(for: scenarioID) {
            return script.frames.count
        }
        return scriptedInputTickCount
    }

    static func runScriptedMatch(
        seed: UInt64,
        p1: FighterDef,
        p2: FighterDef,
        stageId: String,
        scenarioID: String = "",
        fromFile file: String = #filePath
    ) throws -> [UInt64] {
        try runScriptedMatchTracing(
            seed: seed,
            p1: p1,
            p2: p2,
            stageId: stageId,
            scenarioID: scenarioID,
            fromFile: file
        ).hashes
    }

    static func runScriptedMatchTracing(
        seed: UInt64,
        p1: FighterDef,
        p2: FighterDef,
        stageId: String,
        scenarioID: String,
        fromFile file: String = #filePath
    ) throws -> (hashes: [UInt64], trace: KitTrace) {
        let script = KitScripts.script(for: scenarioID)
        let frames = script?.frames ?? legacyScriptFrames()
        if script == nil {
            precondition(frames.count == scriptedInputTickCount)
        }
        var (simulation, _) = try MatchSimulationFactory.make(
            p1PickID: p1.id,
            p1: p1,
            p2PickID: p2.id,
            p2: p2,
            stageId: stageId,
            fromFile: file
        )
        var snap = MatchSimulationFactory.matchSnapshot(
            seed: seed,
            p1: p1,
            p2: p2,
            fighterIDs: [p1.id, p2.id]
        )
        if let script {
            snap.fighters[0].meter = script.meterP1
            snap.fighters[1].meter = script.meterP2
            if let p1X = script.p1XPx {
                snap.fighters[0].position.x = Fixed(pixels: p1X)
            }
            if let p2X = script.p2XPx {
                snap.fighters[1].position.x = Fixed(pixels: p2X)
            }
        }
        var hashes: [UInt64] = []
        hashes.reserveCapacity(frames.count + 1)
        var trace = KitTrace()
        var activeProjectileIDs: Set<UInt32> = []
        for tick in frames {
            hashes.append(snap.stateHash())
            recordTrace(snap, into: &trace, activeProjectileIDs: &activeProjectileIDs)
            simulation.step(inputs: tick, snapshot: &snap)
            for event in snap.events {
                trace.events.append((event.kind, event.moveID))
            }
        }
        hashes.append(snap.stateHash())
        recordTrace(snap, into: &trace, activeProjectileIDs: &activeProjectileIDs)
        return (hashes, trace)
    }

    private static func legacyScriptFrames() -> [[InputFrame]] {
        [
            [.p1Forward, .neutral],
            [.p1LP, .neutral],
            [.neutral, .p2BackBlock],
            [.p1HP, .p2LK],
            [.neutral, .neutral],
        ]
    }

    private static func recordTrace(
        _ snap: GameSnapshot,
        into trace: inout KitTrace,
        activeProjectileIDs: inout Set<UInt32>
    ) {
        for fighter in snap.fighters where !fighter.activeMoveID.isEmpty {
            trace.moveIDs.insert(fighter.activeMoveID)
        }
        if snap.fighters.count > 0, snap.fighters[0].activeMoveID == "sp_rocket_hp" {
            trace.rocketArmor.append(snap.fighters[0].armorRemaining)
        }
        // Spawn ids restart after an inactive bead is removed, so a new bead can reuse id 1.
        var activeNow: Set<UInt32> = []
        for projectile in snap.projectiles where projectile.active {
            activeNow.insert(projectile.id)
            if !activeProjectileIDs.contains(projectile.id) {
                trace.spawned.append((
                    projectile.id,
                    projectile.velocity.x.raw,
                    projectile.hitsAirborne
                ))
            }
        }
        activeProjectileIDs = activeNow
    }

    static func tickHashes(for scenario: ExpectedHashesCatalog.Scenario, fromFile file: String = #filePath) throws -> [UInt64] {
        let (p1, p2) = try loadFighters(scenario.fighters, fromFile: file)
        switch scenario.kind {
        case .replay:
            guard let replayFile = scenario.replayFile else {
                throw HarnessError.missingReplayFile(scenario.id)
            }
            let replayURL = ContentPaths.replaysDirectory(fromFile: file).appendingPathComponent(replayFile)
            let fixture = try ReplayRunner.load(from: replayURL)
            guard fixture.fighters == scenario.fighters else {
                throw HarnessError.replayFighterMismatch(scenario.id, fixture.fighters, scenario.fighters)
            }
            return try runReplay(fixture, stageId: scenario.stageId, fromFile: file)
        case .cpu:
            guard let matchSeed = scenario.matchSeed,
                  let tickLimit = scenario.tickLimit,
                  let p1Name = scenario.p1Difficulty,
                  let p2Name = scenario.p2Difficulty,
                  let p1Diff = parseDifficulty(p1Name),
                  let p2Diff = parseDifficulty(p2Name)
            else {
                throw HarnessError.incompleteCPUScenario(scenario.id)
            }
            let (_, _, hashes) = try runCPUVsCPU(
                matchSeed: matchSeed,
                p1: p1,
                p2: p2,
                stageId: scenario.stageId,
                p1Difficulty: p1Diff,
                p2Difficulty: p2Diff,
                tickLimit: tickLimit,
                fromFile: file
            )
            return hashes
        case .script:
            guard let seed = scenario.scriptSeed else {
                throw HarnessError.incompleteScriptScenario(scenario.id)
            }
            return try runScriptedMatch(
                seed: seed,
                p1: p1,
                p2: p2,
                stageId: scenario.stageId,
                scenarioID: scenario.id,
                fromFile: file
            )
        }
    }

    private static func parseDifficulty(_ name: String) -> Difficulty? {
        switch name.lowercased() {
        case "easy": return .easy
        case "normal": return .normal
        case "hard": return .hard
        default: return nil
        }
    }

    enum HarnessError: Error, CustomStringConvertible {
        case needTwoFighters([String])
        case missingReplayFile(String)
        case incompleteCPUScenario(String)
        case incompleteScriptScenario(String)
        case replayFighterMismatch(String, [String], [String])

        var description: String {
            switch self {
            case .needTwoFighters(let ids):
                return "need two fighter ids, got \(ids)"
            case .missingReplayFile(let id):
                return "replay scenario \(id) missing replayFile"
            case .incompleteCPUScenario(let id):
                return "cpu scenario \(id) missing seed/difficulty/limit"
            case .incompleteScriptScenario(let id):
                return "script scenario \(id) missing scriptSeed"
            case .replayFighterMismatch(let id, let fixture, let catalog):
                return "replay \(id): fixture fighters \(fixture) != catalog \(catalog)"
            }
        }
    }
}

private extension InputFrame {
    static let p1Forward = InputFrame(direction: .right, buttons: 0)
    static let p1LP = InputFrame(direction: .neutral, buttons: 1 << Button.lightPunch.rawValue)
    static let p1HP = InputFrame(direction: .neutral, buttons: 1 << Button.heavyPunch.rawValue)
    static let p2BackBlock = InputFrame(direction: .left, buttons: 0)
    static let p2LK = InputFrame(direction: .neutral, buttons: 1 << Button.lightKick.rawValue)
    static let neutral = InputFrame()
}