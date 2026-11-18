import Foundation
import FightCore

/// Wires shipped fighter defs into the full simulation stack for integration runs.
enum IntegrationMatchHarness {
    static let shippedFighterIDs = ["greybox", "kestrel", "bruno", "ilse", "rook"]
    static let shippedStageIDs = ["stage1", "stage2"]

    static func loadFighter(_ id: String, fromFile file: String = #filePath) throws -> FighterDef {
        try FighterLoader.loadFighter(from: ContentPaths.fighterDirectory(id, fromFile: file))
    }

    static func loadStageJSON(_ id: String, fromFile file: String = #filePath) throws -> [String: Any] {
        let dir = ContentPaths.stageDirectory(id, fromFile: file)
        let data = try Data(contentsOf: dir.appendingPathComponent("stage.json"))
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "IntegrationMatchHarness", code: 1, userInfo: [NSLocalizedDescriptionKey: "stage.json not an object"])
        }
        return json
    }

    static func moveMetadata(p1: FighterDef, p2: FighterDef) -> [String: MatchMoveMetadata] {
        var map: [String: MatchMoveMetadata] = [:]
        for move in p1.moves + p2.moves {
            map[move.id] = MatchMoveMetadata(
                meterGain: move.meterGain,
                hitstop: move.hitstop,
                isSuper: move.inputKind == .superMove
            )
        }
        return map
    }

    static func simulation(p1: FighterDef, p2: FighterDef) -> Simulation {
        var stepper = FighterStepper()
        stepper.registerDefinition(p1)
        stepper.registerDefinition(p2)
        let context = CollisionMatchContext(fighterDefs: [p1, p2])
        return Simulation(
            motion: MotionParser(),
            fighterStep: stepper,
            collision: CollisionResolver(context: context),
            matchDirect: MatchDirector(moveMetadata: moveMetadata(p1: p1, p2: p2))
        )
    }

    static func snapshot(seed: UInt64, p1: FighterDef, p2: FighterDef) -> GameSnapshot {
        var snap = SimulationBootstrap.greyboxMatch(seed: seed)
        snap.fighterIDs = [p1.id, p2.id]
        snap.fighters[0].health = p1.health
        snap.fighters[1].health = p2.health
        return snap
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
        p1: FighterDef,
        p2: FighterDef,
        maxTicks: Int = 600
    ) -> [UInt64] {
        var sim = simulation(p1: p1, p2: p2)
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
        p1Difficulty: Difficulty,
        p2Difficulty: Difficulty,
        tickLimit: Int32
    ) -> (snapshot: GameSnapshot, ticks: Int32, finalHash: UInt64) {
        let profile1 = DifficultyProfile.seeded(difficulty: p1Difficulty, matchSeed: matchSeed ^ 0x1111)
        let profile2 = DifficultyProfile.seeded(difficulty: p2Difficulty, matchSeed: matchSeed ^ 0x2222)
        let ai1 = CPUAIController(profile: profile1)
        let ai2 = CPUAIController(profile: profile2)
        var sim = simulation(p1: p1, p2: p2)
        var snap = snapshot(seed: matchSeed, p1: p1, p2: p2)
        var ticks: Int32 = 0
        let limit = tickLimit > 0 ? tickLimit : MatchRules.roundTickLimit
        while ticks < limit, !snap.rules.matchOver {
            var rng = snap.rng
            let frames = [
                ai1.inputs(for: .p1, snapshot: snap, rng: &rng),
                ai2.inputs(for: .p2, snapshot: snap, rng: &rng),
            ]
            snap.rng = rng
            step(simulation: &sim, snapshot: &snap, inputs: frames)
            ticks &+= 1
        }
        return (snap, ticks, snap.stateHash())
    }
}