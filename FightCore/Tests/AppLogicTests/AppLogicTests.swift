import XCTest
@testable import AppLogic

final class AppLogicTests: XCTestCase {
    func testPlaceholderPhase() {
        XCTAssertEqual(AppLogicMarker.phase, 0)
    }
}