public struct MatchDirectingStub: MatchDirecting {
    public init() {}

    public mutating func applyRules(snapshot: inout GameSnapshot) {
        guard snapshot.fighters.count >= 2 else { return }
        snapshot.rules.roundTick &+= 1
        snapshot.tick &+= 1
        if snapshot.rules.roundTick >= MatchRules.roundTickLimit {
            let p1 = snapshot.fighters[0].health
            let p2 = snapshot.fighters[1].health
            snapshot.rules.roundOver = true
            if p1 > p2 {
                snapshot.rules.p1RoundsWon &+= 1
            } else if p2 > p1 {
                snapshot.rules.p2RoundsWon &+= 1
            }
        }
    }
}