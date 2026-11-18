import XCTest
import FightCore
@testable import AppLogic

final class CameraAndSheetTests: XCTestCase {
    func testCameraTracksFighters() {
        var snap = SimulationBootstrap.greyboxMatch()
        snap.fighters[0].position = Vec2(x: Fixed(pixels: -40), y: .zero)
        snap.fighters[1].position = Vec2(x: Fixed(pixels: 40), y: .zero)
        let cam = FightCameraMath.compute(snapshot: snap)
        XCTAssertEqual(cam.scrollX, 0)

        snap.fighters[0].position = Vec2(x: Fixed(pixels: 200), y: .zero)
        snap.fighters[1].position = Vec2(x: Fixed(pixels: 280), y: .zero)
        let cam2 = FightCameraMath.compute(snapshot: snap)
        XCTAssertGreaterThan(cam2.scrollX, 0)
    }

    func testSpriteSheetLoaderGreybox() throws {
        let sheet = ContentPaths.greyboxDirectory(fromFile: #filePath)
            .appendingPathComponent("sheet.json")
        let frames = try SpriteSheetLoader.loadFrames(fromSheetJSON: sheet)
        XCTAssertFalse(frames.isEmpty)
        let idx = SpriteSheetLoader.indexByName(frames)
        XCTAssertNotNil(idx["idle_0"])
    }
}