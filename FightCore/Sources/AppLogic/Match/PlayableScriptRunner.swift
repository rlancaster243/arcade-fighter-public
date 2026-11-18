import FightCore

/// Scripted tick runner using the same simulation wiring as playable matches.
public enum PlayableScriptRunner {
    public static func tickHashes(
        p1: FighterDef,
        p2: FighterDef,
        stageId: String,
        seed: UInt64,
        frames: [[InputFrame]],
        fromFile: String = #filePath
    ) throws -> [UInt64] {
        var (simulation, _) = try MatchSimulationFactory.make(
            p1PickID: p1.id,
            p1: p1,
            p2PickID: p2.id,
            p2: p2,
            stageId: stageId,
            fromFile: fromFile
        )
        var snap = MatchSimulationFactory.matchSnapshot(
            seed: seed,
            p1: p1,
            p2: p2,
            fighterIDs: [p1.id, p2.id]
        )
        var hashes: [UInt64] = []
        hashes.reserveCapacity(frames.count + 1)
        for tick in frames {
            hashes.append(snap.stateHash())
            simulation.step(inputs: tick, snapshot: &snap)
        }
        hashes.append(snap.stateHash())
        return hashes
    }
}