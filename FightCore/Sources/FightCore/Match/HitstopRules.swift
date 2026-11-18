enum HitstopRules {
    /// Super moves use at least 10 ticks of hitstop (super freeze).
    static let superHitstopMinimum: Int32 = 10

    static func applyEvents(
        snapshot: inout GameSnapshot,
        moveMetadata: [String: MatchMoveMetadata]
    ) {
        var peak: Int32 = snapshot.rules.hitstopRemaining

        for event in snapshot.events {
            guard let meta = moveMetadata[event.moveID] else { continue }
            switch event.kind {
            case .hit, .block, .chip, .throwHit:
                var stop = meta.hitstop
                if meta.isSuper, stop < superHitstopMinimum {
                    stop = superHitstopMinimum
                }
                if stop > peak {
                    peak = stop
                }
            default:
                break
            }
        }

        snapshot.rules.hitstopRemaining = peak
    }
}