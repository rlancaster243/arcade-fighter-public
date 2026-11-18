import FightCore

/// Per-roster move metadata with composite keys when `move.id` repeats across fighters.
public struct MoveMetadataTable: Sendable, Equatable {
    public let resolver: MatchMoveMetadataResolver
    private var inputKindByFighterMove: [String: MoveInputKind]
    private var inputKindByMoveID: [String: MoveInputKind]

    public init(fighterDefs: [FighterDef]) {
        resolver = MatchMoveMetadataResolver(fighterDefs: fighterDefs)
        var kindsComposite: [String: MoveInputKind] = [:]
        var kindsFlat: [String: MoveInputKind] = [:]
        for def in fighterDefs {
            for move in def.moves {
                let key = MoveMetadataKey.compose(fighterID: def.id, moveID: move.id)
                kindsComposite[key] = move.inputKind
                if kindsFlat[move.id] == nil {
                    kindsFlat[move.id] = move.inputKind
                }
            }
        }
        inputKindByFighterMove = kindsComposite
        inputKindByMoveID = kindsFlat
    }

    public func metadata(fighterID: String, moveID: String) -> MatchMoveMetadata? {
        var snap = GameSnapshot(fighterIDs: [fighterID, fighterID])
        let meta = resolver.metadata(for: .p1, moveID: moveID, in: snap)
        return meta.hitstop == 0 && meta.meterGain == 0 && !meta.isSuper ? nil : meta
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