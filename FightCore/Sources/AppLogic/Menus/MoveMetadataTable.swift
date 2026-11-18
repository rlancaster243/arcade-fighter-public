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
                let key = FightCore.MoveMetadataKey.compose(fighterID: def.id, moveID: move.id)
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
        inputKindByFighterMove[FightCore.MoveMetadataKey.compose(fighterID: fighterID, moveID: moveID)]
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
    /// Keys definitions by roster pick ids used in `GameSnapshot.fighterIDs` (not raw bundle ids).
    public static func keyedByRosterPick(
        p1PickID: String,
        p1: FighterDef,
        p2PickID: String,
        p2: FighterDef
    ) -> [String: FighterDef] {
        var map: [String: FighterDef] = [:]
        map[p1PickID] = relabeled(p1, pickID: p1PickID)
        map[p2PickID] = relabeled(p2, pickID: p2PickID)
        return map
    }

    public static func rosterOrdered(
        p1PickID: String,
        p1: FighterDef,
        p2PickID: String,
        p2: FighterDef
    ) -> [FighterDef] {
        [relabeled(p1, pickID: p1PickID), relabeled(p2, pickID: p2PickID)]
    }

    private static func relabeled(_ def: FighterDef, pickID: String) -> FighterDef {
        var copy = def
        copy.id = pickID
        return copy
    }
}