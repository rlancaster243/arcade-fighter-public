import AppLogic
import XCTest
import FightCore

final class FighterCommandLoaderTests: XCTestCase {
    func testKestrelBindsRimeVariantsAndWhiteoutToBothPunches() throws {
        let commands = try FighterCommandLoader.load(id: "kestrel")
        let rimeLK = commands.filter { $0.moveID == "sp_rime_lk" }
        XCTAssertEqual(rimeLK.count, 1)
        XCTAssertEqual(rimeLK[0].motion, .qcf236)
        XCTAssertEqual(rimeLK[0].buttons, MoveCommandTable.bit(.lightKick))
        let rimeHK = commands.filter { $0.moveID == "sp_rime_hk" }
        XCTAssertEqual(rimeHK.count, 1)
        XCTAssertEqual(rimeHK[0].buttons, MoveCommandTable.bit(.heavyKick))
        let whiteout = commands.filter { $0.moveID == "super_whiteout" }
        XCTAssertEqual(whiteout.count, 2)
        XCTAssertTrue(whiteout.allSatisfy { $0.motion == .super236236 })
        XCTAssertEqual(
            Set(whiteout.map(\.buttons)),
            [MoveCommandTable.bit(.lightPunch), MoveCommandTable.bit(.heavyPunch)]
        )
    }

    func testThrowRowRequiresLightPunchAndLightKick() throws {
        let commands = try FighterCommandLoader.load(id: "bruno")
        let toss = commands.filter { $0.moveID == "throw_lp_lk" }
        XCTAssertEqual(toss.count, 1)
        XCTAssertNil(toss[0].motion)
        XCTAssertEqual(
            toss[0].buttons,
            MoveCommandTable.bit(.lightPunch) | MoveCommandTable.bit(.lightKick)
        )
    }
}
