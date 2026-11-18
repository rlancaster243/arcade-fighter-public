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

    /// Plan 5 P7 / 9.5 Q8 and prompt L10: whiff, hit, block, KO, round start, and time-over
    /// are distinct cues, and `Content/Audio/` stays within 700,000 bytes.
    func testSixDistinctCuesWithinAudioBudget() throws {
        let dir = L10ContentPaths.audioDirectory()
        let data = try Data(contentsOf: dir.appendingPathComponent("manifest.json"))
        let manifest = try JSONDecoder().decode(AudioManifest.self, from: data)
        let fileByID = Dictionary(uniqueKeysWithValues: manifest.clips.map { ($0.id, $0.file) })

        let required: [(cue: String, id: String, file: String)] = [
            ("whiff", "whiff", "whiff.wav"),
            ("hit", "hit_light", "hit_light.wav"),
            ("block", "block", "block.wav"),
            ("KO", "ko", "ko.wav"),
            ("round start", "round_start", "round_start.wav"),
            ("time-over", "time_over", "time_over.wav"),
        ]

        var cueBytes: [String: Data] = [:]
        for cue in required {
            XCTAssertEqual(fileByID[cue.id], cue.file, "missing \(cue.cue) cue \(cue.id)")
            let wav = dir.appendingPathComponent(cue.file)
            let bytes = try Data(contentsOf: wav)
            XCTAssertGreaterThan(bytes.count, 44, cue.file)
            XCTAssertEqual(bytes.prefix(4), Data("RIFF".utf8), cue.file)
            XCTAssertEqual(bytes.dropFirst(8).prefix(4), Data("WAVE".utf8), cue.file)
            cueBytes[cue.file] = bytes
        }
        XCTAssertEqual(Set(cueBytes.keys).count, required.count)
        let uniquePayloads = Set(cueBytes.values.map { Data($0) })
        XCTAssertEqual(uniquePayloads.count, required.count, "the six cues must not share a waveform")

        let total = try audioDirectoryByteTotal(at: dir)
        XCTAssertLessThanOrEqual(
            total,
            700_000,
            "Content/Audio is \(total) bytes; budget is 700000"
        )
    }

    /// `SFXEventPlayer` plays the six cues. App audio is macOS-only, so this locks the mapping from source.
    func testEventPlayerMapsSixCues() throws {
        let sourceURL = L10ContentPaths.repoRoot()
            .appendingPathComponent("App/Audio/SFXEventPlayer.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let patterns = [
            #"case\s+\.whiff\s*:\s*return\s+"whiff""#,
            #"case\s+\.timeOver\s*:\s*return\s+"time_over""#,
            #"case\s+\.block\s*:\s*return\s+"block""#,
            #"case\s+\.knockdown\s*:\s*return\s+"ko""#,
            #"case\s+\.roundStart\s*:\s*return\s+"round_start""#,
            #"return\s+"hit_light""#,
            #"return\s+"hit_heavy""#,
        ]
        for pattern in patterns {
            let expression = try NSRegularExpression(pattern: pattern)
            let range = NSRange(source.startIndex..<source.endIndex, in: source)
            XCTAssertNotNil(
                expression.firstMatch(in: source, range: range),
                "SFXEventPlayer missing cue mapping /\(pattern)/"
            )
        }
    }

    private func audioDirectoryByteTotal(at dir: URL) throws -> UInt64 {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: dir,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            XCTFail("cannot list \(dir.path)")
            return 0
        }
        var total: UInt64 = 0
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: keys)
            if values.isRegularFile == true {
                total += UInt64(values.fileSize ?? 0)
            }
        }
        return total
    }
}