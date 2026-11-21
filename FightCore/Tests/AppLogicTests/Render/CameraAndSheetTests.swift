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

    /// Regression: frames were passed to SpriteKit as pixels with a top anchor, so every
    /// fighter drew a squashed copy of its whole sheet hanging below the floor line.
    func testSheetFrameMapsToSpriteKitUnitRectAndFeetAnchor() {
        let stance = SpriteSheetFrame(name: "stance_1", x: 112, y: 0, w: 112, h: 112, anchorX: 56, anchorY: 112)
        let geo = stance.spriteKitGeometry(sheetWidth: 224, sheetHeight: 112)
        XCTAssertEqual(geo.textureX, 0.5)
        XCTAssertEqual(geo.textureY, 0)
        XCTAssertEqual(geo.textureWidth, 0.5)
        XCTAssertEqual(geo.textureHeight, 1)
        XCTAssertEqual(geo.anchorX, 0.5)
        XCTAssertEqual(geo.anchorY, 0, "bottom-centre sheet anchor must be SpriteKit y = 0 (feet)")
    }

    func testSheetFrameFlipsRowOriginForMultiRowSheets() {
        // Top row of a 2-row sheet sits in the upper half of SpriteKit's bottom-left unit space.
        let topRow = SpriteSheetFrame(name: "a", x: 0, y: 0, w: 64, h: 64, anchorX: 32, anchorY: 64)
        XCTAssertEqual(topRow.spriteKitGeometry(sheetWidth: 128, sheetHeight: 128).textureY, 0.5)
        let bottomRow = SpriteSheetFrame(name: "b", x: 0, y: 64, w: 64, h: 64, anchorX: 32, anchorY: 64)
        XCTAssertEqual(bottomRow.spriteKitGeometry(sheetWidth: 128, sheetHeight: 128).textureY, 0)
    }

    func testShippedSheetFramesStayInsideTheirSheets() throws {
        for id in ["greybox", "kestrel", "bruno", "ilse", "rook"] {
            let dir = ContentPaths.fighterDirectory(id, fromFile: #filePath)
            let frames = try SpriteSheetLoader.loadFrames(fromSheetJSON: dir.appendingPathComponent("sheet.json"))
            let (w, h) = try pngSize(dir.appendingPathComponent("\(id).png"))
            for frame in frames {
                let geo = frame.spriteKitGeometry(sheetWidth: Double(w), sheetHeight: Double(h))
                XCTAssertGreaterThanOrEqual(geo.textureX, 0, "\(id)/\(frame.name)")
                XCTAssertGreaterThanOrEqual(geo.textureY, 0, "\(id)/\(frame.name)")
                XCTAssertLessThanOrEqual(geo.textureX + geo.textureWidth, 1, "\(id)/\(frame.name)")
                XCTAssertLessThanOrEqual(geo.textureY + geo.textureHeight, 1, "\(id)/\(frame.name)")
            }
        }
    }

    func testAtlasRoutingDrawsTheBundleThatLoaded() {
        let builtIn = MatchSimulationFactory.builtInFallbackContentID
        // Before a match starts (no content ids yet) each slot draws its pick.
        XCTAssertEqual(
            FighterAtlasRouting.atlasIDs(fighterIDs: ["kestrel", "bruno"], contentIDs: []),
            ["kestrel", "bruno"]
        )
        // Greybox fallback draws greybox; the built-in fallback has no sheet.
        XCTAssertEqual(
            FighterAtlasRouting.atlasIDs(fighterIDs: ["kestrel", "bruno"], contentIDs: ["greybox", builtIn]),
            ["greybox", nil]
        )
        // Short or empty entries fall back to the pick.
        XCTAssertEqual(
            FighterAtlasRouting.atlasIDs(fighterIDs: ["kestrel", "bruno"], contentIDs: ["", "bruno"]),
            ["kestrel", "bruno"]
        )
        XCTAssertEqual(
            FighterAtlasRouting.atlasIDs(fighterIDs: ["kestrel", "bruno"], contentIDs: ["greybox"]),
            ["greybox", "bruno"]
        )
    }

    private func pngSize(_ url: URL) throws -> (Int, Int) {
        let bytes = [UInt8](try Data(contentsOf: url).prefix(24))
        XCTAssertEqual(bytes.count, 24)
        func be32(_ at: Int) -> Int {
            bytes[at..<at + 4].reduce(0) { ($0 << 8) | Int($1) }
        }
        return (be32(16), be32(20))
    }
}