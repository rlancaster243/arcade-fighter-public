import FightCore

/// Builds the playable match simulation stack (stage bounds, roster metadata, fighters).
public enum MatchSimulationFactory {
    public static func make(
        p1PickID: String,
        p1: FighterDef,
        p2PickID: String,
        p2: FighterDef,
        stageId: String,
        fromFile: String = #filePath
    ) throws -> (simulation: Simulation, metadata: MoveMetadataTable) {
        let bounds = try StageBoundsLoader.playBounds(stageId: stageId, fromFile: fromFile)
        let defs = FighterDefinitionMap.rosterOrdered(
            p1PickID: p1PickID,
            p1: p1,
            p2PickID: p2PickID,
            p2: p2
        )
        let defMap = FighterDefinitionMap.keyedByRosterPick(
            p1PickID: p1PickID,
            p1: p1,
            p2PickID: p2PickID,
            p2: p2
        )
        let metadataTable = MoveMetadataTable(fighterDefs: defs)
        let context = CollisionMatchContext(
            fighterDefs: defs,
            playLeftPx: bounds.playLeftPx,
            playRightPx: bounds.playRightPx
        )
        // Commands come from the bundle that actually loaded (`p1.id`, e.g. "greybox" after a
        // fallback) but are keyed by the roster pick, because `MotionParser` matches against
        // `GameSnapshot.fighterIDs`, which holds pick ids.
        let p1Commands = try commands(contentID: p1.id, pickID: p1PickID, fromFile: fromFile)
        let p2Commands = try commands(contentID: p2.id, pickID: p2PickID, fromFile: fromFile)
        let simulation = Simulation(
            motion: MotionParser(commands: MoveCommandTable(commands: p1Commands + p2Commands)),
            fighterStep: FighterStepper(definitions: defMap),
            collision: CollisionResolver(context: context),
            matchDirect: RosterMatchDirector(metadataTable: metadataTable)
        )
        return (simulation, metadataTable)
    }

    /// Content id for the in-code, moveless fighter used when neither the pick nor greybox loads.
    /// It has no bundle on disk, so the factory gives it no commands instead of reading one.
    public static let builtInFallbackContentID = "builtin_fallback"

    /// Last resort when no bundle loads: default stats, no moves, keyed by the roster pick.
    public static func builtInFallbackFighter() -> FighterDef {
        FighterDef(id: builtInFallbackContentID, displayName: "Fallback", gamePlan: "fallback")
    }

    private static func commands(contentID: String, pickID: String, fromFile: String) throws -> [MoveCommand] {
        guard contentID != builtInFallbackContentID else { return [] }
        return try FighterCommandLoader.load(id: contentID, fromFile: fromFile).map { command in
            var keyed = command
            keyed.fighterID = pickID
            return keyed
        }
    }

    public static func matchSnapshot(
        seed: UInt64,
        p1: FighterDef,
        p2: FighterDef,
        fighterIDs: [String]
    ) -> GameSnapshot {
        var snap = SimulationBootstrap.greyboxMatch(seed: seed)
        snap.fighterIDs = fighterIDs
        snap.fighterStartHealth = [p1.health, p2.health]
        snap.fighters[0].health = p1.health
        snap.fighters[1].health = p2.health
        return snap
    }

    public static func loadFighter(id: String, fromFile: String = #filePath) -> FighterDef {
        let directory = ContentPaths.fighterDirectory(id, fromFile: fromFile)
        if let def = try? FighterLoader.loadFighter(from: directory) {
            return def
        }
        let greybox = ContentPaths.greyboxDirectory(fromFile: fromFile)
        return (try? FighterLoader.loadFighter(from: greybox)) ?? builtInFallbackFighter()
    }
}
