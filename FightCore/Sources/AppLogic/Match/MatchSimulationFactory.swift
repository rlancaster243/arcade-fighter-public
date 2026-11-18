import FightCore

/// Builds the playable match simulation stack (stage bounds, roster metadata, fighters).
public enum MatchSimulationFactory {
    public static func make(
        p1: FighterDef,
        p2: FighterDef,
        stageId: String,
        fromFile: String = #filePath
    ) throws -> (simulation: Simulation, metadata: MoveMetadataTable) {
        let bounds = try StageBoundsLoader.playBounds(stageId: stageId, fromFile: fromFile)
        let defs = [p1, p2]
        let defMap = FighterDefinitionMap.keyedByFighterID(p1: p1, p2: p2)
        let metadataTable = MoveMetadataTable(fighterDefs: defs)
        let context = CollisionMatchContext(
            fighterDefs: defs,
            playLeftPx: bounds.playLeftPx,
            playRightPx: bounds.playRightPx
        )
        let simulation = Simulation(
            motion: MotionParser(),
            fighterStep: FighterStepper(definitions: defMap),
            collision: CollisionResolver(context: context),
            matchDirect: RosterMatchDirector(metadataTable: metadataTable)
        )
        return (simulation, metadataTable)
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
        return (try? FighterLoader.loadFighter(from: greybox))
            ?? FighterDef(id: "greybox", displayName: "Greybox", gamePlan: "fallback")
    }
}