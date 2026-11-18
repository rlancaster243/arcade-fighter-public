import AppLogic
import FightCore

/// `MatchDirector` driven by roster-aware move metadata (no bare `move.id` collisions).
struct RosterMatchDirector: MatchDirecting {
    var resolver: MatchMoveMetadataResolver

    init(metadataTable: MoveMetadataTable) {
        resolver = metadataTable.resolver
    }

    mutating func applyRules(snapshot: inout GameSnapshot) {
        var director = MatchDirector(metadata: resolver)
        director.applyRules(snapshot: &snapshot)
    }
}