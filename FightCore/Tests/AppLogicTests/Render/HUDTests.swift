import XCTest
import FightCore
@testable import AppLogic

final class HUDTests: XCTestCase {
    /// T-APPLOGIC-HUD: snapshot → HUD model and bar geometry.
    func testT_APPLOGIC_HUD_modelAndBarLayout() {
        var snap = SimulationBootstrap.greyboxMatch(seed: 1)
        snap.fighters[0].health = 750
        snap.fighters[1].health = 250
        snap.fighters[0].meter = 400
        snap.fighters[1].meter = 1000
        snap.rules.roundTick = 120

        let model = HUDLayout.model(from: snap)
        XCTAssertEqual(model.p1HealthCap, 1000)
        XCTAssertEqual(model.p2HealthCap, 1000)
        XCTAssertEqual(model.p1Health, 750)
        XCTAssertEqual(model.p2Health, 250)
        XCTAssertEqual(model.p1Meter, 400)
        XCTAssertEqual(model.p2Meter, 1000)
        XCTAssertEqual(model.timerSeconds, snap.rules.displaySeconds)

        let p1 = HUDLayout.p1HealthBarFrame()
        let p2 = HUDLayout.p2HealthBarFrame()
        XCTAssertEqual(p1.w, p2.w)
        XCTAssertLessThan(p1.x, p2.x)
        XCTAssertEqual(p1.y, p2.y)

        let fillP1 = HUDLayout.filledWidth(current: 750, cap: 1000, barWidth: p1.w)
        XCTAssertEqual(fillP1, 90)
        let fillP2 = HUDLayout.filledWidth(current: 250, cap: 1000, barWidth: p2.w)
        XCTAssertEqual(fillP2, 30)

        let timer = HUDLayout.timerFrame()
        XCTAssertEqual(timer.x + timer.w / 2, SceneConstants.width / 2)
    }
}