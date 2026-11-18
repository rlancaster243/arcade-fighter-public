import FightCore

/// `MatchDirector` with per-slot move metadata resolution (same stack as playable `LocalMatchSession`).
public struct RosterMatchDirector: MatchDirecting {
    public var metadataTable: MoveMetadataTable

    public init(metadataTable: MoveMetadataTable) {
        self.metadataTable = metadataTable
    }

    public mutating func applyRules(snapshot: inout GameSnapshot) {
        var director = MatchDirector(moveMetadata: metadataTable.directorMap(for: snapshot))
        director.applyRules(snapshot: &snapshot)
    }
}