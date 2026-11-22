import XCTest
import FightCore
@testable import AppLogic

/// Frame names are the contract with scripts/art/gen_fighters.py.
final class SpriteSelectionTests: XCTestCase {
    private func fighter(_ kind: FighterStateKind, move: String = "", stateTick: Int32 = 0) -> FighterState {
        var f = FighterState(position: Vec2(x: .zero, y: .zero), facingRight: true, health: 1000)
        f.kind = kind
        f.activeMoveID = move
        f.stateTick = stateTick
        return f
    }

    func testIdleCyclesThroughFourFrames() {
        let names = Set((0..<80).map { SpriteSelection.frameCandidates(for: fighter(.idle), tick: Int32($0)).first! })
        XCTAssertEqual(names, ["idle_0", "idle_1", "idle_2", "idle_3"])
    }

    func testWalkCyclesSixFramesAndBackwardsReverses() {
        let fwd = (0..<36).map { SpriteSelection.frameCandidates(for: fighter(.walkForward), tick: Int32($0)).first! }
        XCTAssertEqual(Set(fwd).count, 6)
        let back = (0..<36).map { SpriteSelection.frameCandidates(for: fighter(.walkBack), tick: Int32($0)).first! }
        XCTAssertEqual(back, fwd.map { name in
            let i = Int(name.split(separator: "_").last!)!
            return "walk_\(5 - i)"
        })
    }

    func testAttackPhasesMapToMoveFrames() {
        XCTAssertEqual(SpriteSelection.frameCandidates(for: fighter(.attackStartup, move: "norm_lp"), tick: 0).first, "norm_lp_0")
        XCTAssertEqual(SpriteSelection.frameCandidates(for: fighter(.attackActive, move: "norm_lp"), tick: 0).first, "norm_lp_1")
        XCTAssertEqual(SpriteSelection.frameCandidates(for: fighter(.attackRecovery, move: "norm_lp"), tick: 0).first, "norm_lp_2")
    }

    func testAirborneUsesVelocityForRiseApexFall() {
        var f = fighter(.airborne)
        f.velocity = Vec2(x: .zero, y: Fixed(raw: -10 * Fixed.scale))
        XCTAssertEqual(SpriteSelection.frameCandidates(for: f, tick: 0).first, "jump_1")
        f.velocity = Vec2(x: .zero, y: .zero)
        XCTAssertEqual(SpriteSelection.frameCandidates(for: f, tick: 0).first, "jump_2")
        f.velocity = Vec2(x: .zero, y: Fixed(raw: 10 * Fixed.scale))
        XCTAssertEqual(SpriteSelection.frameCandidates(for: f, tick: 0).first, "jump_3")
    }

    func testEveryStateEndsWithTheIdleFallback() {
        let kinds: [FighterStateKind] = [
            .idle, .walkForward, .walkBack, .crouch, .jumpStartup, .airborne, .landing,
            .attackStartup, .attackActive, .attackRecovery, .hitstun, .blockstunStand, .blockstunCrouch,
            .knockdown, .getup, .throwStartup, .throwing, .beingThrown, .ko, .win,
        ]
        for kind in kinds {
            let c = SpriteSelection.frameCandidates(for: fighter(kind, move: "x"), tick: 7)
            XCTAssertEqual(c.last, "idle_0", "\(kind)")
            XCTAssertFalse(c.isEmpty)
        }
    }

    func testShippedSheetsContainEveryGenericFrame() throws {
        let generic = ["idle_0", "idle_1", "idle_2", "idle_3", "crouch_0", "jump_0", "jump_1", "jump_2", "jump_3",
                       "land_0", "block_0", "block_1", "hit_0", "hit_1", "down_0", "down_1", "getup_0", "ko_0",
                       "win_0", "win_1", "throw_0", "thrown_0", "proj_0", "proj_1"] + (0..<6).map { "walk_\($0)" }
        for id in ["kestrel", "bruno", "ilse", "rook", "greybox"] {
            let dir = ContentPaths.fighterDirectory(id, fromFile: #filePath)
            let frames = try SpriteSheetLoader.loadFrames(fromSheetJSON: dir.appendingPathComponent("sheet.json"))
            let names = Set(frames.map(\.name))
            for name in generic {
                XCTAssertTrue(names.contains(name), "\(id) sheet missing \(name)")
            }
            let def = try JSONSerialization.jsonObject(with: Data(contentsOf: dir.appendingPathComponent("fighter.json"))) as! [String: Any]
            for move in def["moves"] as! [[String: Any]] {
                let mid = move["id"] as! String
                for phase in 0..<3 {
                    XCTAssertTrue(names.contains("\(mid)_\(phase)"), "\(id) sheet missing \(mid)_\(phase)")
                }
            }
        }
    }
}
