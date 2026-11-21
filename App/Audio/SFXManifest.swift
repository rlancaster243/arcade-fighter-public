import Foundation

/// Offline synthesized SFX catalog under `Content/Audio/`.
struct SFXManifest: Decodable, Sendable {
    struct Clip: Decodable, Sendable, Identifiable {
        let id: String
        let file: String
        let gainQ8: Int
        let loop: Bool?
    }

    let schemaVersion: Int
    let sampleRate: Int
    let clips: [Clip]

    func clip(id: String) -> Clip? {
        clips.first { $0.id == id }
    }
}

enum SFXContent {
    static func manifestURL(audioDirectory: URL) -> URL {
        audioDirectory.appendingPathComponent("manifest.json")
    }

    static func loadManifest(audioDirectory: URL) throws -> SFXManifest {
        let data = try Data(contentsOf: manifestURL(audioDirectory: audioDirectory))
        return try JSONDecoder().decode(SFXManifest.self, from: data)
    }
}
