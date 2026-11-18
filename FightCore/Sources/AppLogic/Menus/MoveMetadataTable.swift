import FightCore

/// Per-roster move metadata with composite keys when `move.id` repeats across fighters.
public enum MoveMetadataKey: Sendable, Equatable {
    public static func compose(fighterID: String, moveID: String) -> String {
        "\(fighterID)::\(moveID)"
    }
}

public struct MoveMetadataTable: Sendable, Equatable {
    private var byFighterMove: [String: MatchMoveMetadata]
    private var byMoveID: [String: MatchMoveMetadata]
    private var inputKindByFighterMove: [String: MoveInputKind]
    private var inputKindByMoveID: [String: MoveInputKind]

    public init(fighterDefs: [FighterDef]) {
        var composite: [String: MatchMoveMetadata] = [:]
        var flat: [String: MatchMoveMetadata] = [:]
        var kindsComposite: [String: MoveInputKind] = [:]
        var kindsFlat: [String: MoveInputKind] = [:]
        for def in fighterDefs {
            for move in def.moves {
                let key = MoveMetadataKey.compose(fighterID: def.id, moveID: move.id)
                let meta = MatchMoveMetadata(
                    meterGain: move.meterGain,
                    hitstop: move.hitstop,
                    isSuper: move.inputKind == .superMove
                )
                composite[key] = meta
                kindsComposite[key] = move.inputKind
                if flat[move.id] == nil {
                    flat[move.id] = meta
                    kindsFlat[move.id] = move.inputKind
                }
            }
        }
        byFighterMove = composite
        byMoveID = flat
        inputKindByFighterMove = kindsComposite
        inputKindByMoveID = kindsFlat
    }

    public func metadata(fighterID: String, moveID: String) -> MatchMoveMetadata? {
        byFighterMove[MoveMetadataKey.compose(fighterID: fighterID, moveID: moveID)]
            ?? byMoveID[moveID]
    }

    public func metadata(moveID: String) -> MatchMoveMetadata? {
        byMoveID[moveID]
    }

    /// Map for `MatchDirector`, preferring slot-specific entries when fighters differ.
    public func directorMap(for snapshot: GameSnapshot) -> [String: MatchMoveMetadata] {
        var map = byMoveID
        for (index, fighter) in snapshot.fighters.enumerated() {
            guard index < snapshot.fighterIDs.count else { continue }
            let fighterID = snapshot.fighterIDs[index]
            let moveID = fighter.activeMoveID
            guard !moveID.isEmpty, let meta = metadata(fighterID: fighterID, moveID: moveID) else {
                continue
            }
            map[moveID] = meta
        }
        return map
    }

    public func moveInputKind(fighterID: String, moveID: String) -> MoveInputKind? {
        inputKindByFighterMove[MoveMetadataKey.compose(fighterID: fighterID, moveID: moveID)]
            ?? inputKindByMoveID[moveID]
    }

    public func moveInputKindForEvent(_ event: GameEvent, snapshot: GameSnapshot) -> MoveInputKind? {
        let idx = Int(event.attacker.rawValue)
        guard idx < snapshot.fighterIDs.count else {
            return inputKindByMoveID[event.moveID]
        }
        return moveInputKind(fighterID: snapshot.fighterIDs[idx], moveID: event.moveID)
    }
}

public enum FighterDefinitionMap {
    public static func keyedByFighterID(p1: FighterDef, p2: FighterDef) -> [String: FighterDef] {
        var map: [String: FighterDef] = [:]
        map[p1.id] = p1
        map[p2.id] = p2
        return map
    }
}