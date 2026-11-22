import XCTest
@testable import AppLogic

final class StageArtTests: XCTestCase {
    func testStage2LayersLoadBackToFrontAndFilesExist() throws {
        let layers = try StageArt.layers(stageID: "stage2")
        XCTAssertEqual(layers.map(\.id), ["sky", "bells", "floor"])
        XCTAssertEqual(layers.map(\.parallaxQ8), [26, 77, 256])
        for l in layers { XCTAssertTrue(FileManager.default.fileExists(atPath: l.imageURL.path), l.id) }
    }

    func testStage1SingleBackgroundIsOneFullParallaxLayer() throws {
        let layers = try StageArt.layers(stageID: "stage1")
        XCTAssertEqual(layers.count, 1)
        XCTAssertEqual(layers[0].parallaxQ8, 256)
        XCTAssertTrue(FileManager.default.fileExists(atPath: layers[0].imageURL.path))
    }

    func testParallaxOffsets() {
        XCTAssertEqual(StageArt.layerOffsetX(scrollX: 100, parallaxQ8: 256), -100)
        XCTAssertEqual(StageArt.layerOffsetX(scrollX: 100, parallaxQ8: 0), 0)
        XCTAssertEqual(StageArt.layerOffsetX(scrollX: 256, parallaxQ8: 26), -26)
    }
}
