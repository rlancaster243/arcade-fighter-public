import FightCore

/// Builds simulation snapshots from menu `MatchSetup` (platform-free).
public enum MatchBootstrap {
    public static func snapshot(for setup: MatchSetup, seed: UInt64 = 0xAFC) -> GameSnapshot {
        var snap = SimulationBootstrap.greyboxMatch(seed: seed)
        snap.fighterIDs = [setup.p1.id, setup.p2.id]
        return snap
    }
}