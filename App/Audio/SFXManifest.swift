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
    static func manifestURL(repoRoot: URL? = nil) -> URL {
        let root = repoRoot ?? Bundle.main.bundleURL.deletingLastPathComponent()
        return root.appendingPathComponent("Content/Audio/manifest.json")
    }

    static func loadManifest(repoRoot: URL? = nil) throws -> SFXManifest {
        let url = manifestURL(repoRoot: repoRoot)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SFXManifest.self, from: data)
    }

    static func audioDirectory(repoRoot: URL? = nil) -> URL {
        let root = repoRoot ?? Bundle.main.bundleURL.deletingLastPathComponent()
        return root.appendingPathComponent("Content/Audio", isDirectory: true)
    }
}