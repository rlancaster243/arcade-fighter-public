import XCTest
import FightCore
@testable import AppLogic

/// Regression: a normal attack connected again on every active frame, so a 108-damage heavy
/// punch dealt 324 and rounds ended in about five blows. Uses the shipped fighters.
final class SingleHitPerAttackTests: XCTestCase {
    private func damageAndHits(_ button: Button, moveID: String, attackerID: String, contactAlreadySet: Bool = false, defenderArmor: Int32 = 0) throws -> (damage: Int32, hits: Int, expected: Int32) {
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
            if tick == 0 {
                XCTAssertEqual(snap.fighters[0].activeMoveID, moveID)
                // As if the attacker's own projectile had just connected during startup.
                if contactAlreadySet { snap.fighters[0].attackContact = true }
                snap.fighters[1].armorRemaining = defenderArmor
            }
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

    /// The single-hit gate must not read `attackContact`: the attacker's projectile sets that too,
    /// and the follow-up strike would pass straight through.
    func testAStrikeStillLandsAfterTheAttackersProjectileMadeContact() throws {
        let r = try damageAndHits(.heavyPunch, moveID: "norm_hp", attackerID: "kestrel", contactAlreadySet: true)
        XCTAssertEqual(r.hits, 1)
        XCTAssertEqual(r.damage, r.expected)
    }

    /// One hit of armor absorbs the whole blow: the strike must not land on a later active frame.
    func testOneHitOfArmorAbsorbsTheWholeStrike() throws {
        let r = try damageAndHits(.heavyPunch, moveID: "norm_hp", attackerID: "kestrel", defenderArmor: 1)
        XCTAssertEqual(r.hits, 0)
        XCTAssertEqual(r.damage, 0)
    }
}
