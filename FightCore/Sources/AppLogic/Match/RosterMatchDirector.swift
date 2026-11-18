import FightCore

/// `MatchDirector` with per-slot move metadata resolution (same stack as playable `LocalMatchSession`).
public struct RosterMatchDirector: MatchDirecting {
    public var resolver: MatchMoveMetadataResolver

    public init(metadataTable: MoveMetadataTable) {
        resolver = metadataTable.resolver
    }

    public mutating func applyRules(snapshot: inout GameSnapshot) {
        var director = MatchDirector(metadata: resolver)
        director.applyRules(snapshot: &snapshot)
    }
}