import XCTest
@testable import AppLogic

final class DisplayLayoutTests: XCTestCase {
    func testIntegerScaleLetterbox() {
        let vp = DisplayLayout.viewport(viewWidth: 800, viewHeight: 600)
        XCTAssertEqual(vp.integerScale, 2)
        XCTAssertEqual(vp.contentWidth, 384 * 2)
        XCTAssertEqual(vp.contentHeight, 216 * 2)
        XCTAssertEqual(vp.offsetX, (800 - vp.contentWidth) / 2)
        XCTAssertEqual(vp.offsetY, (600 - vp.contentHeight) / 2)
    }

    func testForcedWindowScale() {
        let vp = DisplayLayout.viewport(viewWidth: 2000, viewHeight: 1200, forcedScale: 3)
        XCTAssertEqual(vp.integerScale, 3)
        XCTAssertEqual(vp.contentWidth, 1152)
    }

    func testMinWindowSize() {
        let size = DisplayLayout.minWindowSize(scale: 2)
        XCTAssertEqual(size.width, 768)
        XCTAssertEqual(size.height, 432)
    }
}