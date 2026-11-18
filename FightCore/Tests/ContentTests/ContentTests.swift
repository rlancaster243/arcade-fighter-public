import XCTest
@testable import FightCore

final class ContentTests: XCTestCase {
    func testGreyboxContentBundleInRepo() throws {
        let def = try FighterLoader.loadFighter(from: ContentPaths.greyboxDirectory())
        XCTAssertFalse(def.gamePlan.isEmpty)
    }
}