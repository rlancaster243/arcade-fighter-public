import FightCore

/// Builds simulation snapshots from menu `MatchSetup` (platform-free).
public enum MatchBootstrap {
    public static func snapshot(
        for setup: MatchSetup,
        seed: UInt64 = 0xAFC,
        fromFile: String = #filePath
    ) -> GameSnapshot {
        let p1 = MatchSimulationFactory.loadFighter(id: setup.p1.id, fromFile: fromFile)
        let p2 = MatchSimulationFactory.loadFighter(id: setup.p2.id, fromFile: fromFile)
        return MatchSimulationFactory.matchSnapshot(
            seed: seed,
            p1: p1,
            p2: p2,
            fighterIDs: [setup.p1.id, setup.p2.id]
        )
    }
}