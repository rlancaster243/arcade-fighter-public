import Foundation
import XCTest

private struct StageJSON: Decodable {
    struct Layer: Decodable {
        let id: String
        let image: String
        let parallaxQ8: Int
        let zOrder: Int
    }

    let schemaVersion: Int
    let id: String
    let displayName: String
    let width: Int
    let height: Int
    let floorY: Int
    let layers: [Layer]
    let ambientLoop: String?
}

final class L10StageTests: XCTestCase {
    func testStage2BellTowerCloisterFiles() throws {
        let dir = L10ContentPaths.stage2Directory()
        let data = try Data(contentsOf: dir.appendingPathComponent("stage.json"))
        let stage = try JSONDecoder().decode(StageJSON.self, from: data)
        XCTAssertEqual(stage.schemaVersion, 1)
        XCTAssertEqual(stage.id, "stage2")
        XCTAssertEqual(stage.displayName, "Bell Tower Cloister")
        XCTAssertEqual(stage.layers.count, 3)
        for layer in stage.layers {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: dir.appendingPathComponent(layer.image).path),
                "missing layer \(layer.image)"
            )
        }
        if let ambient = stage.ambientLoop {
            let audioDir = L10ContentPaths.audioDirectory()
            let manifest = try Data(contentsOf: audioDir.appendingPathComponent("manifest.json"))
            XCTAssertTrue(String(data: manifest, encoding: .utf8)?.contains(ambient) == true)
        }
    }
}