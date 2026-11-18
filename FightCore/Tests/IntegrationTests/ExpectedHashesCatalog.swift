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
        case tickHashLengthMismatch(String, expected: Int, actual: Int)
        case cpuTickHashLengthOutOfRange(String, count: Int, maxInclusive: Int)
        case incompleteCPUScenario(String)
        case missingReplayFile(String)

        var description: String {
            switch self {
            case .duplicateScenarioID(let id):
                return "duplicate scenario id: \(id)"
            case .emptyTickHashes(let id):
                return "scenario \(id) has empty tickHashes"
            case .tickHashLengthMismatch(let id, let expected, let actual):
                return "scenario \(id): tickHashes count \(actual) != expected \(expected)"
            case .cpuTickHashLengthOutOfRange(let id, let count, let max):
                return "scenario \(id): cpu tickHashes count \(count) outside 1...\(max)"
            case .incompleteCPUScenario(let id):
                return "cpu scenario \(id) missing tickLimit"
            case .missingReplayFile(let id):
                return "replay scenario \(id) missing replayFile"
            }
        }
    }

    func validateTickHashLengths(fromFile file: String = #filePath) throws {
        for scenario in scenarios {
            switch scenario.kind {
            case .replay:
                let expected = try Self.replayTickHashCount(for: scenario, fromFile: file)
                guard scenario.tickHashes.count == expected else {
                    throw ValidationError.tickHashLengthMismatch(scenario.id, expected: expected, actual: scenario.tickHashes.count)
                }
            case .script:
                let expected = IntegrationMatchHarness.scriptedTickCount(for: scenario.id) + 1
                guard scenario.tickHashes.count == expected else {
                    throw ValidationError.tickHashLengthMismatch(scenario.id, expected: expected, actual: scenario.tickHashes.count)
                }
            case .cpu:
                guard let tickLimit = scenario.tickLimit else {
                    throw ValidationError.incompleteCPUScenario(scenario.id)
                }
                let maxCount = Int(tickLimit) + 1
                let count = scenario.tickHashes.count
                guard (1...maxCount).contains(count) else {
                    throw ValidationError.cpuTickHashLengthOutOfRange(scenario.id, count: count, maxInclusive: maxCount)
                }
            }
        }
    }

    private static func replayTickHashCount(for scenario: Scenario, fromFile file: String) throws -> Int {
        guard let replayFile = scenario.replayFile else {
            throw ValidationError.missingReplayFile(scenario.id)
        }
        let replayURL = ContentPaths.replaysDirectory(fromFile: file).appendingPathComponent(replayFile)
        let fixture = try ReplayRunner.load(from: replayURL)
        return fixture.inputs.count + 1
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
        try catalog.validateTickHashLengths(fromFile: file)
        return catalog
    }
}