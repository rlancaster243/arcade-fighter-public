import Foundation
import FightCore

struct ExpectedHashesCatalog: Decodable, Sendable {
    struct Scenario: Decodable, Sendable {
        let id: String
        let finalHash: UInt64
        let tickHashes: [UInt64]?
    }

    let schemaVersion: Int32
    let scenarios: [Scenario]

    func scenario(id: String) -> Scenario? {
        scenarios.first { $0.id == id }
    }

    static func load(fromFile file: String = #filePath) throws -> ExpectedHashesCatalog {
        let root = ContentPaths.repoRoot(fromFile: file)
        let url = root
            .appendingPathComponent("FightCore/Tests/FightCoreTests/Contracts/expected-hashes.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ExpectedHashesCatalog.self, from: data)
    }
}