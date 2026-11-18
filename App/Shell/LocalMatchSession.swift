import AppLogic
import FightCore
import Foundation

/// Fixed-step local match driver: loads fighters, runs `Simulation`, publishes `GameSnapshot`.
@MainActor
final class LocalMatchSession: ObservableObject {
    private var simulation = Simulation()
    private var snapshot: GameSnapshot?
    private var setup: MatchSetup?
    private var cpu: CPUAIController?
    private var metadataTable = MoveMetadataTable(fighterDefs: [])
    private var lastTickTime: Date?
    private var accumulator: TimeInterval = 0
    private var paused = false

    private let tickDuration = 1.0 / 60.0
    private let maxCatchUpSteps = 5

    var isRunning: Bool { setup != nil && snapshot != nil }
    var isPaused: Bool { paused && isRunning }

    func start(setup: MatchSetup, initialSnapshot: GameSnapshot, model: MenuShellModel) {
        let p1 = loadFighter(id: setup.p1.id)
        let p2 = loadFighter(id: setup.p2.id)
        let defs = [p1, p2]
        let defMap = FighterDefinitionMap.keyedByFighterID(p1: p1, p2: p2)
        metadataTable = MoveMetadataTable(fighterDefs: defs)
        let context = CollisionMatchContext(fighterDefs: defs)

        simulation = Simulation(
            motion: MotionParser(),
            fighterStep: FighterStepper(definitions: defMap),
            collision: CollisionResolver(context: context),
            matchDirect: RosterMatchDirector(metadataTable: metadataTable)
        )

        var snap = initialSnapshot
        snap.fighterIDs = [setup.p1.id, setup.p2.id]
        snapshot = snap
        self.setup = setup
        cpu = setup.mode == .arcade
            ? CPUAIController(difficulty: setup.difficulty, matchSeed: snap.rng.state)
            : nil
        lastTickTime = nil
        accumulator = 0
        paused = false
        model.matchSnapshot = snap
    }

    func pause() {
        guard isRunning else { return }
        paused = true
        lastTickTime = nil
    }

    func resume() {
        guard isRunning, paused else { return }
        paused = false
        lastTickTime = nil
        accumulator = 0
    }

    func stop() {
        setup = nil
        snapshot = nil
        cpu = nil
        lastTickTime = nil
        accumulator = 0
        paused = false
        metadataTable = MoveMetadataTable(fighterDefs: [])
    }

    func advance(
        to date: Date,
        input: InputCoordinator,
        model: MenuShellModel,
        sfx: SFXEventPlayer
    ) {
        guard var snap = snapshot, !paused else { return }

        if lastTickTime == nil {
            lastTickTime = date
            return
        }
        guard let last = lastTickTime else { return }
        accumulator += date.timeIntervalSince(last)
        lastTickTime = date

        var steps = 0
        while accumulator >= tickDuration, steps < maxCatchUpSteps {
            steps += 1
            accumulator -= tickDuration
            guard !snap.rules.matchOver else { break }

            var frames = input.framesForTick()
            if let cpu {
                var rng = snap.rng
                frames[1] = cpu.inputs(for: .p2, snapshot: snap, rng: &rng)
                snap.rng = rng
            }

            simulation.step(inputs: frames, snapshot: &snap)
            snapshot = snap
            model.matchSnapshot = snap
            sfx.handle(events: snap.events, snapshot: snap, metadata: metadataTable)

            if snap.rules.matchOver {
                model.endMatch(snapshot: snap)
                stop()
                return
            }
        }
    }

    private func loadFighter(id: String) -> FighterDef {
        let directory = ContentPaths.fighterDirectory(id, fromFile: #filePath)
        if let def = try? FighterLoader.loadFighter(from: directory) {
            return def
        }
        let greybox = ContentPaths.greyboxDirectory(fromFile: #filePath)
        return (try? FighterLoader.loadFighter(from: greybox))
            ?? FighterDef(id: "greybox", displayName: "Greybox", gamePlan: "fallback")
    }
}