/// Alternate costume for slot 1 (P2) when both slots draw the same fighter, so a mirror match
/// stays readable. Convention-based: the alternate sheet is `<id>_alt.png` beside `<id>.png`
/// and shares its `sheet.json`; a bundle without one falls back to the normal sheet.
public enum FighterSkin {
    public static let altSuffix = "_alt"

    /// Sheet key for a slot: `id`, or `id_alt` for slot 1 when `otherSlotID` is the same fighter.
    public static func sheetName(id: String, slot: Int, otherSlotID: String?) -> String {
        slot == 1 && otherSlotID == id ? id + altSuffix : id
    }

    /// Per-slot sheet keys for routed atlas ids (nil entries, the built-in fallback, stay nil).
    public static func sheetNames(atlasIDs: [String?]) -> [String?] {
        atlasIDs.indices.map { slot in
            guard let id = atlasIDs[slot] else { return nil }
            let other = slot == 1 ? atlasIDs[0] : nil
            return sheetName(id: id, slot: slot, otherSlotID: other)
        }
    }

    /// Bundle id behind a sheet key (strips the alternate suffix).
    public static func bundleID(ofSheet name: String) -> String {
        name.hasSuffix(altSuffix) ? String(name.dropLast(altSuffix.count)) : name
    }
}
