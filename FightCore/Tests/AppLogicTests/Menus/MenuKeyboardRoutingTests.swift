import AppLogic
import XCTest

final class MenuKeyboardRoutingTests: XCTestCase {
    func testMatchPauseHotkeysOnlyDeliversPauseAndCancel() {
        XCTAssertEqual(
            MenuKeyboardRouting.menuCommand(keyCode: MenuKeyboardKeyCode.pauseP, mode: .matchPauseHotkeysOnly),
            .pause
        )
        XCTAssertEqual(
            MenuKeyboardRouting.menuCommand(keyCode: MenuKeyboardKeyCode.escape, mode: .matchPauseHotkeysOnly),
            .cancel
        )
    }

    func testMatchPauseHotkeysOnlyIgnoresMenuNavigationKeys() {
        let navigationCodes: [UInt16] = [
            MenuKeyboardKeyCode.ansiW,
            MenuKeyboardKeyCode.ansiS,
            MenuKeyboardKeyCode.ansiA,
            MenuKeyboardKeyCode.ansiD,
            MenuKeyboardKeyCode.upArrow,
            MenuKeyboardKeyCode.downArrow,
            MenuKeyboardKeyCode.leftArrow,
            MenuKeyboardKeyCode.rightArrow,
            MenuKeyboardKeyCode.returnKey,
            MenuKeyboardKeyCode.space,
        ]
        for code in navigationCodes {
            XCTAssertNil(
                MenuKeyboardRouting.menuCommand(keyCode: code, mode: .matchPauseHotkeysOnly),
                "key 0x\(String(code, radix: 16)) must not be menu-stolen during a round"
            )
        }
    }

    func testFullNavigationStillMapsMovementAndPause() {
        XCTAssertEqual(
            MenuKeyboardRouting.menuCommand(keyCode: MenuKeyboardKeyCode.ansiW, mode: .fullNavigation),
            .up
        )
        XCTAssertEqual(
            MenuKeyboardRouting.menuCommand(keyCode: MenuKeyboardKeyCode.pauseP, mode: .fullNavigation),
            .pause
        )
    }
}