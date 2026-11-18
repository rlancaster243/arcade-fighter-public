import Foundation
import XCTest

private struct AudioManifest: Decodable {
    struct Clip: Decodable {
        let id: String
        let file: String
        let gainQ8: Int
        let loop: Bool?
    }

    let schemaVersion: Int
    let sampleRate: Int
    let clips: [Clip]
}

final class L10AudioTests: XCTestCase {
    func testSynthesizedSFXManifestOnDisk() throws {
        let dir = L10ContentPaths.audioDirectory()
        let data = try Data(contentsOf: dir.appendingPathComponent("manifest.json"))
        let manifest = try JSONDecoder().decode(AudioManifest.self, from: data)
        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertGreaterThanOrEqual(manifest.clips.count, 8)
        let ids = Set(manifest.clips.map(\.id))
        XCTAssertTrue(ids.contains("hit_light"))
        XCTAssertTrue(ids.contains("ambient_bells"))
        for clip in manifest.clips {
            let wav = dir.appendingPathComponent(clip.file)
            XCTAssertTrue(FileManager.default.fileExists(atPath: wav.path), clip.file)
            let attrs = try FileManager.default.attributesOfItem(atPath: wav.path)
            let size = attrs[.size] as? UInt64 ?? 0
            XCTAssertGreaterThan(size, 44, "WAV too small: \(clip.file)")
        }
    }
}