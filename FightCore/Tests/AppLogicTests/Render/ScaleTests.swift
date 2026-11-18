import XCTest
@testable import AppLogic

final class ScaleTests: XCTestCase {
    /// T-APPLOGIC-SCALE: largest integer scale with centered letterbox.
    func testT_APPLOGIC_SCALE_largestIntegerScaleAndLetterbox() {
        let layout = ViewScaleMath.largestIntegerScale(viewportWidth: 1920, viewportHeight: 1080)
        XCTAssertEqual(layout.scale, 5)
        XCTAssertEqual(layout.contentWidth, SceneConstants.width * 5)
        XCTAssertEqual(layout.contentHeight, SceneConstants.height * 5)
        XCTAssertEqual(layout.contentOffsetX, (1920 - 1920) / 2)
        XCTAssertEqual(layout.contentOffsetY, (1080 - 1080) / 2)

        let small = ViewScaleMath.largestIntegerScale(viewportWidth: 500, viewportHeight: 300)
        XCTAssertEqual(small.scale, 1)
        XCTAssertEqual(small.contentWidth, 384)
        XCTAssertEqual(small.contentHeight, 216)
        XCTAssertEqual(small.contentOffsetX, (500 - 384) / 2)
        XCTAssertEqual(small.contentOffsetY, (300 - 216) / 2)

        let odd = ViewScaleMath.largestIntegerScale(viewportWidth: 770, viewportHeight: 433)
        XCTAssertEqual(odd.scale, 2)
        XCTAssertEqual(odd.contentOffsetX, (770 - 768) / 2)
        XCTAssertEqual(odd.contentOffsetY, (433 - 432) / 2)
    }

    func testT_APPLOGIC_SCALE_minimumScaleIsOne() {
        let tiny = ViewScaleMath.largestIntegerScale(viewportWidth: 200, viewportHeight: 100)
        XCTAssertEqual(tiny.scale, 1)
        XCTAssertGreaterThanOrEqual(tiny.contentOffsetX, 0)
    }
}