import XCTest
import FightCore
@testable import AppLogic

/// Regression: a normal attack connected again on every active frame, so a 108-damage heavy
/// punch dealt 324 and rounds ended in about five blows. Uses the shipped fighters.
final class SingleHitPerAttackTests: XCTestCase {
    private func damageAndHits(_ button: Button, moveID: String, attackerID: String) throws -> (damage: Int32, hits: Int, expected: Int32) {
        let p1 = try FighterLoader.loadFighter(from: ContentPaths.fighterDirectory(attackerID, fromFile: #filePath))
        let p2 = try FighterLoader.loadFighter(from: ContentPaths.fighterDirectory("rook", fromFile: #filePath))
        var sim = try IntegrationMatchHarness.simulation(p1: p1, p2: p2, stageId: "stage1")
        var snap = IntegrationMatchHarness.snapshot(seed: 7, p1: p1, p2: p2)
        snap.fighters[1].position.x = Fixed(raw: snap.fighters[0].position.x.raw + 45 * Fixed.scale)
        let start = snap.fighters[1].health
        var hits = 0
        for tick in 0..<60 {
            var frame = InputFrame()
            if tick == 0 { frame.set(button, pressed: true) }
            sim.step(inputs: [frame, InputFrame()], snapshot: &snap)
            hits += snap.events.filter { $0.kind == .hit && $0.moveID == moveID }.count
        }
        let move = try XCTUnwrap(p1.moves.first { $0.id == moveID })
        return (start - snap.fighters[1].health, hits, move.damage)
    }

    func testAHeavyPunchHitsOnceForItsListedDamage() throws {
        let r = try damageAndHits(.heavyPunch, moveID: "norm_hp", attackerID: "kestrel")
        XCTAssertEqual(r.hits, 1)
        XCTAssertEqual(r.damage, r.expected)
    }

    func testALightPunchHitsOnceForItsListedDamage() throws {
        let r = try damageAndHits(.lightPunch, moveID: "norm_lp", attackerID: "kestrel")
        XCTAssertEqual(r.hits, 1)
        XCTAssertEqual(r.damage, r.expected)
    }
}
