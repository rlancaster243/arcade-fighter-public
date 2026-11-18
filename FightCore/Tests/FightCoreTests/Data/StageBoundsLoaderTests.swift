import XCTest
@testable import FightCore

final class StageBoundsLoaderTests: XCTestCase {
    func testUnknownStageDoesNotFallBackToDefaultBounds() {
        XCTAssertThrowsError(try StageBoundsLoader.playBounds(stageId: "__no_such_stage__")) { error in
            let text = String(describing: error)
            XCTAssertTrue(
                text.contains("could not read") || text.contains("no leftBound"),
                "expected surfaced stage error, got: \(text)"
            )
        }
    }
}