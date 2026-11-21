/// Selectable fighters, in character-select order. Index 0 is the default pick, and the arcade
/// ladder takes its opponents in this order.
///
/// Every id must have a bundle at `Content/Fighters/<id>/<id>.contentbundle`. Greybox stays out of
/// the roster: it is the load fallback and test fighter, not a shipped character.
/// `FighterRosterTests` fails if a shipped fighter bundle is missing from this list.
public enum FighterRoster: Sendable, Equatable {
    public static let entries: [String] = ["kestrel", "bruno", "ilse", "rook"]

    /// Bundles under `Content/Fighters` that are deliberately not selectable.
    public static let nonSelectableContentIDs: Set<String> = ["greybox"]

    public static var count: Int { entries.count }

    public static func id(at index: Int) -> String {
        let wrapped = positiveMod(index, entries.count)
        return entries[wrapped]
    }

    public static func index(of id: String) -> Int {
        entries.firstIndex(of: id) ?? 0
    }

    private static func positiveMod(_ value: Int, _ modulus: Int) -> Int {
        guard modulus > 0 else { return 0 }
        let rem = value % modulus
        return rem >= 0 ? rem : rem + modulus
    }
}
