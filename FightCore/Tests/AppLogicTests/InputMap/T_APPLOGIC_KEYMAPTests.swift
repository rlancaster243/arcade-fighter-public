import FightCore
import XCTest
@testable import AppLogic

/// T-APPLOGIC-KEYMAP: platform-free key map, defaults, remap, and sampling.
final class T_APPLOGIC_KEYMAPTests: XCTestCase {
    func testMacVirtualKeyCodesMatchHitoolbox() {
        for (key, expected) in MacVirtualKeyCode.hitoolboxExpectations {
            XCTAssertEqual(key.rawValue, expected, "\(key) kVK mismatch")
        }
    }

    func testDefaultPlayerOneBindings() {
        let bindings = KeyMapDefaults.playerOne
        XCTAssertEqual(bindings.up, MacVirtualKeyCode.ansiW.rawValue)
        XCTAssertEqual(bindings.left, MacVirtualKeyCode.ansiA.rawValue)
        XCTAssertEqual(bindings.down, MacVirtualKeyCode.ansiS.rawValue)
        XCTAssertEqual(bindings.right, MacVirtualKeyCode.ansiD.rawValue)
        XCTAssertEqual(bindings.lightPunch, MacVirtualKeyCode.ansiF.rawValue)
        XCTAssertEqual(bindings.heavyPunch, MacVirtualKeyCode.ansiG.rawValue)
        XCTAssertEqual(bindings.lightKick, MacVirtualKeyCode.ansiH.rawValue)
        XCTAssertEqual(bindings.heavyKick, MacVirtualKeyCode.ansiJ.rawValue)
    }

    func testPlayerTwoNumpadLayout() {
        let bindings = KeyMapDefaults.playerTwo(layout: .numpad)
        XCTAssertEqual(bindings.lightPunch, MacVirtualKeyCode.keypad4.rawValue)
        XCTAssertEqual(bindings.heavyPunch, MacVirtualKeyCode.keypad5.rawValue)
        XCTAssertEqual(bindings.lightKick, MacVirtualKeyCode.keypad1.rawValue)
        XCTAssertEqual(bindings.heavyKick, MacVirtualKeyCode.keypad2.rawValue)
        XCTAssertEqual(bindings.up, MacVirtualKeyCode.upArrow.rawValue)
    }

    func testPlayerTwoAlternateLayout() {
        let bindings = KeyMapDefaults.playerTwo(layout: .alternate)
        XCTAssertEqual(bindings.lightPunch, MacVirtualKeyCode.ansiI.rawValue)
        XCTAssertEqual(bindings.heavyPunch, MacVirtualKeyCode.ansiO.rawValue)
        XCTAssertEqual(bindings.lightKick, MacVirtualKeyCode.ansiK.rawValue)
        XCTAssertEqual(bindings.heavyKick, MacVirtualKeyCode.ansiL.rawValue)
    }

    func testDirectionComposerDiagonal() {
        XCTAssertEqual(
            DirectionComposer.compose(up: true, down: false, left: true, right: false),
            .upLeft
        )
        XCTAssertEqual(
            DirectionComposer.compose(up: false, down: true, left: false, right: true),
            .downRight
        )
    }

    func testKeyboardSamplerProducesQFCPunch() {
        var sampler = KeyboardInputSampler(bindings: KeyMapDefaults.playerOne)
        sampler.keyDown(MacVirtualKeyCode.ansiS.rawValue)
        sampler.keyDown(MacVirtualKeyCode.ansiD.rawValue)
        sampler.keyDown(MacVirtualKeyCode.ansiF.rawValue)
        let frame = sampler.sampleFrame()
        XCTAssertEqual(frame.direction, .downRight)
        XCTAssertTrue(frame.pressed(.lightPunch))
    }

    func testInputMapSessionRoutesPlayersIndependently() {
        var session = InputMapSession()
        session.keyDown(MacVirtualKeyCode.ansiF.rawValue)
        session.keyDown(MacVirtualKeyCode.keypad4.rawValue)
        let frames = session.keyboardFrames()
        XCTAssertTrue(frames[0].pressed(.lightPunch))
        XCTAssertTrue(frames[1].pressed(.lightPunch))
        XCTAssertFalse(frames[0].pressed(.heavyPunch))
    }

    func testRemapSettingsApplyPlayerTwoLayout() {
        var settings = InputRemapSettings()
        settings.applyPlayerTwoLayout(.alternate)
        XCTAssertEqual(settings.playerTwoLayout, .alternate)
        XCTAssertEqual(settings.playerTwoBindings.lightPunch, MacVirtualKeyCode.ansiI.rawValue)
    }

    func testRemapCustomKey() {
        var settings = InputRemapSettings()
        settings.remapKey(player: .p1, slot: .lightPunch, to: MacVirtualKeyCode.ansiO.rawValue)
        XCTAssertEqual(settings.playerOneBindings.lightPunch, MacVirtualKeyCode.ansiO.rawValue)
    }

    func testGamepadDirectionDeadzone() {
        XCTAssertEqual(GamepadDirectionSampler.direction(horizontal: 0.2, vertical: 0.0), .neutral)
        XCTAssertEqual(GamepadDirectionSampler.direction(horizontal: 0.9, vertical: 0.0), .right)
        XCTAssertEqual(GamepadDirectionSampler.direction(horizontal: -0.9, vertical: 0.6), .upLeft)
    }

    func testGamepadFaceMapToButtons() {
        var sampler = GamepadInputSampler(faceMap: KeyMapDefaults.gamepadFace)
        sampler.setFaceButton(.buttonX, pressed: true)
        sampler.setFaceButton(.buttonB, pressed: true)
        sampler.setStickDirection(.left)
        let frame = sampler.sampleFrame()
        XCTAssertTrue(frame.pressed(.lightPunch))
        XCTAssertTrue(frame.pressed(.heavyKick))
        XCTAssertEqual(frame.direction, .left)
    }

    func testKeyTestModelKeepsRecentEvents() {
        var model = KeyTestModel()
        model.record(keyCode: 0x03, label: "F", player: .p1, slot: .lightPunch, isKeyDown: true)
        XCTAssertEqual(model.recent.count, 1)
        XCTAssertEqual(model.recent[0].slot, .lightPunch)
    }
}