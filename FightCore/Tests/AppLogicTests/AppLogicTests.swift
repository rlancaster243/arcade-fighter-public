import XCTest
@testable import AppLogic

final class AppLogicTests: XCTestCase {
<<<<<<< HEAD
    func testInputMapModuleLoads() {
        XCTAssertEqual(KeyMapDefaults.playerOne.up, MacVirtualKeyCode.ansiW.rawValue)
=======
    func testInitialScreenIsTitle() {
        XCTAssertEqual(MenuShellState.initial.screen, .title)
>>>>>>> d3475e9 (feat(L7): add menu state machine and app shell)
    }

    func testRenderModuleLoads() {
        XCTAssertEqual(SceneConstants.width, 384)
        XCTAssertEqual(SceneConstants.height, 216)
    }
}