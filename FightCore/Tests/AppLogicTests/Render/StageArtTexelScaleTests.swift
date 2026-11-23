import XCTest
@testable import AppLogic

final class StageArtTexelScaleTests: XCTestCase {
    private let dir = URL(fileURLWithPath: "/tmp/stage-fixture", isDirectory: true)

    func testLayersJSONReadsTopLevelTexelScale() {
        let json: [String: Any] = [
            "texelScale": 2,
            "layers": [
                ["id": "sky", "image": "sky.png", "parallaxQ8": 26, "zOrder": 0],
                ["id": "floor", "image": "floor.png", "parallaxQ8": 256, "zOrder": 2],
            ],
        ]
        let layers = StageArt.layers(fromJSON: json, directory: dir)
        XCTAssertEqual(layers.map(\.texelScale), [2, 2])
        XCTAssertEqual(layers.map(\.id), ["sky", "floor"])
        XCTAssertEqual(layers.map(\.parallaxQ8), [26, 256])
    }

    func testTexelScaleDefaultsToOneForLayersAndBackground() {
        let layered = StageArt.layers(fromJSON: ["layers": [["id": "a", "image": "a.png"]]], directory: dir)
        XCTAssertEqual(layered.map(\.texelScale), [1])
        let single = StageArt.layers(fromJSON: ["background": "bg.png"], directory: dir)
        XCTAssertEqual(single.map(\.texelScale), [1])
    }

    func testBackgroundSchemaCarriesTexelScale() {
        let single = StageArt.layers(fromJSON: ["texelScale": 2, "background": "bg.png"], directory: dir)
        XCTAssertEqual(single.map(\.texelScale), [2])
    }

    func testInvalidTexelScaleClampsToOne() {
        let bad: [Any] = [0, -3, "2"]
        for value in bad {
            let l = StageArt.layers(fromJSON: ["texelScale": value, "layers": [["image": "a.png"]]], directory: dir)
            XCTAssertEqual(l.map(\.texelScale), [1], "\(value)")
        }
    }

    func testLayersFromTempDirFixtureViaFile() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("stageart-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try Data(#"{"texelScale":2,"layers":[{"id":"sky","image":"sky.png","zOrder":1},{"id":"far","image":"far.png","zOrder":0}]}"#.utf8)
            .write(to: tmp.appendingPathComponent("stage.json"))
        let layers = try StageArt.layers(fromStageJSON: tmp.appendingPathComponent("stage.json"))
        XCTAssertEqual(layers.map(\.id), ["far", "sky"])
        XCTAssertEqual(layers.map(\.texelScale), [2, 2])
        XCTAssertEqual(layers[0].imageURL, tmp.appendingPathComponent("far.png"))
    }

    func testLogicalSizeDividesByTexelScale() {
        let s = StageArt.logicalSize(pixelWidth: 1536, pixelHeight: 432, texelScale: 2)
        XCTAssertEqual(s.width, 768)
        XCTAssertEqual(s.height, 216)
        XCTAssertEqual(StageArt.logicalSize(pixelWidth: 768, pixelHeight: 216, texelScale: 1), s)
    }

    func testShippedStagesReportPositiveTexelScale() throws {
        for id in ["stage1", "stage2"] {
            for l in try StageArt.layers(stageID: id) { XCTAssertGreaterThanOrEqual(l.texelScale, 1) }
        }
    }
}
