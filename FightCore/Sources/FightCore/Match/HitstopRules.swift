enum HitstopRules {
    /// Super moves use at least 10 ticks of hitstop (super freeze).
    static let superHitstopMinimum: Int32 = 10

    static func applyEvents(
        snapshot: inout GameSnapshot,
        metadata: MatchMoveMetadataResolver
    ) {
        var peak: Int32 = snapshot.rules.hitstopRemaining

        for event in snapshot.events {
            let meta = metadata.metadata(for: event.attacker, moveID: event.moveID, in: snapshot)
            guard meta.hitstop > 0 || meta.isSuper else { continue }
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