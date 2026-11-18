import Foundation
import FightCore

struct ExpectedHashesCatalog: Decodable, Sendable {
    enum ScenarioKind: String, Decodable, Sendable {
        case replay
        case cpu
        case script
    }

    struct Scenario: Decodable, Sendable {
        let id: String
        let kind: ScenarioKind
        let stageId: String
        let fighters: [String]
        let tickHashes: [UInt64]
        let replayFile: String?
        let matchSeed: UInt64?
        let tickLimit: Int32?
        let p1Difficulty: String?
        let p2Difficulty: String?
        let scriptSeed: UInt64?
    }

    let schemaVersion: Int32
    let catalogFighters: [String]
    let scenarios: [Scenario]

    func scenario(id: String) -> Scenario? {
        scenarios.first { $0.id == id }
    }

    func validateUniqueScenarioIDs() throws {
        var seen = Set<String>()
        for scenario in scenarios {
            guard seen.insert(scenario.id).inserted else {
                throw ValidationError.duplicateScenarioID(scenario.id)
            }
        }
    }

    enum ValidationError: Error, CustomStringConvertible {
        case duplicateScenarioID(String)
        case emptyTickHashes(String)

        var description: String {
            switch self {
            case .duplicateScenarioID(let id):
                return "duplicate scenario id: \(id)"
            case .emptyTickHashes(let id):
                return "scenario \(id) has empty tickHashes"
            }
        }
    }

    static func load(fromFile file: String = #filePath) throws -> ExpectedHashesCatalog {
        let root = ContentPaths.repoRoot(fromFile: file)
        let url = root
            .appendingPathComponent("FightCore/Tests/FightCoreTests/Contracts/expected-hashes.json")
        let data = try Data(contentsOf: url)
        let catalog = try JSONDecoder().decode(ExpectedHashesCatalog.self, from: data)
        try catalog.validateUniqueScenarioIDs()
        for scenario in catalog.scenarios where scenario.tickHashes.isEmpty {
            throw ValidationError.emptyTickHashes(scenario.id)
        }
        return catalog
    }
}