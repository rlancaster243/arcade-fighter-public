import XCTest
@testable import AppLogic

final class SpriteSheetScaleTests: XCTestCase {
    private let barePayload = """
    [{"name":"idle_0","x":0,"y":0,"w":112,"h":112,"anchorX":56,"anchorY":110}]
    """
    private let scaledPayload = """
    {"texelScale":2,"frames":[{"name":"idle_0","x":0,"y":0,"w":224,"h":224,"anchorX":112,"anchorY":220}]}
    """

    func testBareArrayDecodesAsTexelScaleOne() throws {
        let sheet = try SpriteSheetLoader.decode(Data(barePayload.utf8))
        XCTAssertEqual(sheet.texelScale, 1)
        XCTAssertEqual(sheet.frames.map(\.name), ["idle_0"])
        XCTAssertEqual(sheet.frames[0].w, 112)
    }

    func testObjectShapeCarriesTexelScale() throws {
        let sheet = try SpriteSheetLoader.decode(Data(scaledPayload.utf8))
        XCTAssertEqual(sheet.texelScale, 2)
        XCTAssertEqual(sheet.frames[0].w, 224)
        XCTAssertEqual(sheet.frames[0].anchorY, 220)
    }

    func testObjectWithoutTexelScaleDefaultsToOne() throws {
        let sheet = try SpriteSheetLoader.decode(Data(#"{"frames":[]}"#.utf8))
        XCTAssertEqual(sheet.texelScale, 1)
        XCTAssertTrue(sheet.frames.isEmpty)
    }

    func testNonPositiveTexelScaleClampsToOne() throws {
        let sheet = try SpriteSheetLoader.decode(Data(#"{"texelScale":0,"frames":[]}"#.utf8))
        XCTAssertEqual(sheet.texelScale, 1)
    }

    func testLoadFramesFromFileKeepsWorkingForBothShapes() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sheetscale-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let bare = dir.appendingPathComponent("bare.json")
        let scaled = dir.appendingPathComponent("scaled.json")
        try Data(barePayload.utf8).write(to: bare)
        try Data(scaledPayload.utf8).write(to: scaled)
        XCTAssertEqual(try SpriteSheetLoader.loadFrames(fromSheetJSON: bare).count, 1)
        XCTAssertEqual(try SpriteSheetLoader.loadFrames(fromSheetJSON: scaled).count, 1)
        XCTAssertEqual(try SpriteSheetLoader.loadSheet(fromSheetJSON: scaled).texelScale, 2)
    }

    func testTwoXSheetYieldsSameLogicalNodeSizeAsOneX() throws {
        let one = try SpriteSheetLoader.decode(Data(
            #"[{"name":"a","x":0,"y":0,"w":112,"h":112,"anchorX":56,"anchorY":110}]"#.utf8))
        let two = try SpriteSheetLoader.decode(Data(
            #"{"texelScale":2,"frames":[{"name":"a","x":0,"y":0,"w":224,"h":224,"anchorX":112,"anchorY":224}]}"#.utf8))
        let s1 = one.frames[0].nodeSize(texelScale: one.texelScale)
        let s2 = two.frames[0].nodeSize(texelScale: two.texelScale)
        XCTAssertEqual(s1.width, 112)
        XCTAssertEqual(s1.height, 112)
        XCTAssertEqual(s1, s2)
    }

    func testAnchorGeometryIsScaleInvariantUnitFraction() {
        let f1 = SpriteSheetFrame(name: "a", x: 0, y: 0, w: 112, h: 112, anchorX: 56, anchorY: 110)
        let f2 = SpriteSheetFrame(name: "a", x: 0, y: 0, w: 224, h: 224, anchorX: 112, anchorY: 220)
        let g1 = f1.spriteKitGeometry(sheetWidth: 896, sheetHeight: 448)
        let g2 = f2.spriteKitGeometry(sheetWidth: 1792, sheetHeight: 896)
        XCTAssertEqual(g1.anchorX, g2.anchorX, accuracy: 1e-9)
        XCTAssertEqual(g1.anchorY, g2.anchorY, accuracy: 1e-9)
    }

    func testNodeSizeIsFractionalWhenNotDivisible() {
        let f = SpriteSheetFrame(name: "a", x: 0, y: 0, w: 225, h: 100, anchorX: 0, anchorY: 0)
        let s = f.nodeSize(texelScale: 2)
        XCTAssertEqual(s.width, 112.5)
        XCTAssertEqual(s.height, 50)
    }
}
