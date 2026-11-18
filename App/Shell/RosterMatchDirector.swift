import AppLogic
import FightCore

/// `MatchDirector` with per-slot move metadata resolution.
struct RosterMatchDirector: MatchDirecting {
    var metadataTable: MoveMetadataTable

    mutating func applyRules(snapshot: inout GameSnapshot) {
        var director = MatchDirector(moveMetadata: metadataTable.directorMap(for: snapshot))
        director.applyRules(snapshot: &snapshot)
    }
}