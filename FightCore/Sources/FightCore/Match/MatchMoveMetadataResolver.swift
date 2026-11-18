/// Keys move metadata by fighter plus move id so rosters can share `move.id` values safely.
public enum MoveMetadataKey: Sendable, Equatable {
    public static func compose(fighterID: String, moveID: String) -> String {
        "\(fighterID)::\(moveID)"
    }
}

public struct MatchMoveMetadataResolver: Sendable, Equatable {
    private var byFighterMove: [String: MatchMoveMetadata]
    private var flatFallback: [String: MatchMoveMetadata]

    public init(fighterDefs: [FighterDef]) {
        var composite: [String: MatchMoveMetadata] = [:]
        for def in fighterDefs {
            for move in def.moves {
                composite[MoveMetadataKey.compose(fighterID: def.id, moveID: move.id)] = MatchMoveMetadata(
                    meterGain: move.meterGain,
                    hitstop: move.hitstop,
                    isSuper: move.inputKind == .superMove
                )
            }
        }
        byFighterMove = composite
        flatFallback = [:]
    }

    public init(flat: [String: MatchMoveMetadata]) {
        byFighterMove = [:]
        flatFallback = flat
    }

    public func metadata(for slot: PlayerSlot, moveID: String, in snapshot: GameSnapshot) -> MatchMoveMetadata {
        guard !moveID.isEmpty else { return MatchMoveMetadata() }
        let idx = Int(slot.rawValue)
        if idx < snapshot.fighterIDs.count {
            let key = MoveMetadataKey.compose(fighterID: snapshot.fighterIDs[idx], moveID: moveID)
            if let meta = byFighterMove[key] {
                return meta
            }
        }
        return flatFallback[moveID] ?? MatchMoveMetadata()
    }
}