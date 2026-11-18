/// Per-slot starting health from content (survives round resets and HUD scaling).
public enum RosterStartHealth {
    public static func health(for slot: PlayerSlot, snapshot: GameSnapshot) -> Int32 {
        let index = slot == .p1 ? 0 : 1
        guard snapshot.fighterStartHealth.indices.contains(index) else {
            return 1000
        }
        return snapshot.fighterStartHealth[index]
    }

    public static func caps(for snapshot: GameSnapshot) -> (p1: Int32, p2: Int32) {
        (
            health(for: .p1, snapshot: snapshot),
            health(for: .p2, snapshot: snapshot)
        )
    }
}