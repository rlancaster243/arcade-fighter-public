import XCTest
@testable import AppLogic

final class AppLogicTests: XCTestCase {
    func testInputMapModuleLoads() {
        XCTAssertEqual(KeyMapDefaults.playerOne.up, MacVirtualKeyCode.ansiW.rawValue)
    }

    func testInitialScreenIsTitle() {
        XCTAssertEqual(MenuShellState.initial.screen, .title)
    }

    func testRenderModuleLoads() {
        XCTAssertEqual(SceneConstants.width, 384)
        XCTAssertEqual(SceneConstants.height, 216)
    }
}