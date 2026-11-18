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
    private var lastTickTime: Date?
    private var accumulator: TimeInterval = 0

    private let tickDuration = 1.0 / 60.0

    var isRunning: Bool { setup != nil && snapshot != nil }

    func start(setup: MatchSetup, initialSnapshot: GameSnapshot, model: MenuShellModel) {
        let defs = loadFighterDefs(p1: setup.p1.id, p2: setup.p2.id)
        let defMap = Dictionary(uniqueKeysWithValues: defs.map { ($0.id, $0) })
        let moveMetadata = Self.moveMetadata(for: defs)
        let context = CollisionMatchContext(fighterDefs: defs)

        simulation = Simulation(
            motion: MotionParser(),
            fighterStep: FighterStepper(definitions: defMap),
            collision: CollisionResolver(context: context),
            matchDirect: MatchDirector(moveMetadata: moveMetadata)
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
        model.matchSnapshot = snap
    }

    func stop() {
        setup = nil
        snapshot = nil
        cpu = nil
        lastTickTime = nil
        accumulator = 0
    }

    func advance(
        to date: Date,
        input: InputCoordinator,
        model: MenuShellModel,
        sfx: SFXEventPlayer
    ) {
        guard var snap = snapshot else { return }

        if lastTickTime == nil {
            lastTickTime = date
            return
        }
        guard let last = lastTickTime else { return }
        accumulator += date.timeIntervalSince(last)
        lastTickTime = date

        while accumulator >= tickDuration {
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
            sfx.handle(events: snap.events)

            if snap.rules.matchOver {
                model.endMatch(snapshot: snap)
                stop()
                return
            }
        }
    }

    private func loadFighterDefs(p1: String, p2: String) -> [FighterDef] {
        [loadFighter(id: p1), loadFighter(id: p2)]
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

    private static func moveMetadata(for defs: [FighterDef]) -> [String: MatchMoveMetadata] {
        var meta: [String: MatchMoveMetadata] = [:]
        for def in defs {
            for move in def.moves {
                meta[move.id] = MatchMoveMetadata(
                    meterGain: move.meterGain,
                    hitstop: move.hitstop,
                    isSuper: move.inputKind == .superMove
                )
            }
        }
        return meta
    }
}