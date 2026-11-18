import XCTest
@testable import AppLogic

final class AppLogicTests: XCTestCase {
<<<<<<< HEAD
    func testInputMapModuleLoads() {
        XCTAssertEqual(KeyMapDefaults.playerOne.up, MacVirtualKeyCode.ansiW.rawValue)
=======
    func testPlaceholderPhase() {
        XCTAssertEqual(AppLogicMarker.phase, 6)
>>>>>>> c17f722 (feat(L6): SpriteKit render lane with AppLogic scale and HUD)
    }
}