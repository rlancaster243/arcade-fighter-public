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
        let decoder = JSONDecoder()
        return try decoder.decode(ExpectedHashesCatalog.self, from: data)
    }
}

private extension ExpectedHashesCatalog.Scenario {
    enum CodingKeys: String, CodingKey {
        case id
        case finalHash
        case tickHashes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        finalHash = try container.decodeHexUInt64(forKey: .finalHash)
        tickHashes = try container.decodeIfPresent([UInt64].self, forKey: .tickHashes)
    }
}

private extension ExpectedHashesCatalog {
    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case scenarios
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int32.self, forKey: .schemaVersion)
        scenarios = try container.decode([Scenario].self, forKey: .scenarios)
    }
}

private extension KeyedDecodingContainer {
    func decodeHexUInt64(forKey key: Key) throws -> UInt64 {
        if let n = try? decode(UInt64.self, forKey: key) {
            return n
        }
        let text = try decode(String.self, forKey: key)
        let trimmed = text.hasPrefix("0x") || text.hasPrefix("0X") ? String(text.dropFirst(2)) : text
        guard let value = UInt64(trimmed, radix: 16) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: self,
                debugDescription: "invalid hex uint64: \(text)"
            )
        }
        return value
    }
}