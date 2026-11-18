/// Built-in roster entries available before lane L9 content lands.
public enum FighterRoster: Sendable, Equatable {
    public static let entries: [String] = ["greybox"]

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