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

    func testStageJSONMissingPlayBoundsFailsClosed() throws {
        let json: [String: Any] = [
            "schemaVersion": 1,
            "id": "fake_stage",
            "displayName": "No bounds",
        ]
        XCTAssertThrowsError(try StageBoundsLoader.playBounds(fromJSON: json, stageId: "fake_stage")) { error in
            guard let boundsError = error as? StageBoundsLoader.StageBoundsError else {
                return XCTFail("expected StageBoundsError, got \(error)")
            }
            if case .missingPlayBounds(let id) = boundsError {
                XCTAssertEqual(id, "fake_stage")
            } else {
                XCTFail("expected missingPlayBounds, got \(boundsError)")
            }
        }
        XCTAssertNotEqual(
            (try? StageBoundsLoader.playBounds(fromJSON: json, stageId: "fake_stage"))?.playLeftPx,
            StageBounds.playLeftPx,
            "must not silently fall back to default play bounds"
        )
    }

    func testStageJSONWithLeftRightBoundsDoesNotUseDefaults() throws {
        let json: [String: Any] = [
            "leftBound": 20,
            "rightBound": 364,
        ]
        let bounds = try StageBoundsLoader.playBounds(fromJSON: json, stageId: "stage1")
        XCTAssertNotEqual(bounds.playLeftPx, StageBounds.playLeftPx)
    }
}