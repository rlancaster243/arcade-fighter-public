/// Chooses which content bundle's sprite sheet draws each fighter slot.
///
/// `GameSnapshot.fighterIDs` holds roster pick ids. After a load fallback the simulation runs a
/// different bundle (greybox, or the built-in fighter), so the renderer must draw that bundle,
/// not the pick, or the visuals stop matching the moves and hitboxes.
public enum FighterAtlasRouting {
    /// One entry per slot in `fighterIDs`: the bundle id to load a sheet from, or nil when the
    /// slot runs the built-in fallback, which has no sheet. `contentIDs` holds the bundle each
    /// slot actually loaded; a missing or empty entry means the pick loaded as itself.
    public static func atlasIDs(fighterIDs: [String], contentIDs: [String]) -> [String?] {
        fighterIDs.indices.map { index in
            let loaded = index < contentIDs.count ? contentIDs[index] : ""
            let id = loaded.isEmpty ? fighterIDs[index] : loaded
            return id == MatchSimulationFactory.builtInFallbackContentID ? nil : id
        }
    }
}
