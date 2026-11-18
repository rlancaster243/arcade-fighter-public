import XCTest
@testable import AppLogic

final class AppLogicTests: XCTestCase {
    func testInputMapModuleLoads() {
        XCTAssertEqual(KeyMapDefaults.playerOne.up, MacVirtualKeyCode.ansiW.rawValue)
    }
}