import XCTest
@testable import FightCore

final class L10FighterTests: XCTestCase {
    func testIlseKitMatchesFixB() throws {
        let (def, raw) = try RosterKitSpec.load("ilse")
        RosterKitSpec.assertIdentity(
            def,
            displayName: "Sister Ilse",
            archetype: "zoner",
            health: 950,
            walkForward: 448,
            walkBack: 512
        )
        XCTAssertEqual(def.moves.count, 10)
        RosterKitSpec.assertNormalsAndThrow(raw)
        RosterKitSpec.assertSpecialNames(raw, names: ["Prayer Bead", "Vesper Step"])
        RosterKitSpec.assertSuper(raw, name: "Rosary Storm", button: "P")
        XCTAssertFalse(raw.contains { $0.motion == "623" })
        XCTAssertTrue(def.moves.contains { $0.inputKind == .throwMove })

        let prayer = RosterKitSpec.rows(raw, name: "Prayer Bead")
        XCTAssertEqual(Set(prayer.map(\.motion)), ["236"])
        XCTAssertEqual(Set(prayer.map(\.button)), ["LP", "HP"])
        let slow = try XCTUnwrap(def.moves.first { $0.id == "sp_prayer_lp" }.flatMap(\.projectile))
        let fast = try XCTUnwrap(def.moves.first { $0.id == "sp_prayer_hp" }.flatMap(\.projectile))
        XCTAssertLessThan(slow.speed, fast.speed)
        XCTAssertEqual(slow.maxOnScreen, 1)
        XCTAssertEqual(fast.maxOnScreen, 1)
        XCTAssertEqual(slow.spawnCount, 1)
        XCTAssertEqual(fast.spawnCount, 1)
        XCTAssertTrue(slow.hitsAirborne)
        XCTAssertTrue(fast.hitsAirborne)

        let step = RosterKitSpec.rows(raw, name: "Vesper Step")
        XCTAssertEqual(Set(step.map(\.motion)), ["214"])
        XCTAssertEqual(Set(step.map(\.button)), ["LK", "HK"])
        let forward = try XCTUnwrap(def.moves.first { $0.id == "sp_vesper_lk" })
        let back = try XCTUnwrap(def.moves.first { $0.id == "sp_vesper_hk" })
        XCTAssertTrue(forward.velocities.contains { $0.x >= 32 * Fixed.scale })
        XCTAssertTrue(back.velocities.contains { $0.x <= -32 * Fixed.scale })
        XCTAssertGreaterThanOrEqual(forward.recovery, 18)
        XCTAssertGreaterThanOrEqual(back.recovery, 18)

        let storm = try XCTUnwrap(def.moves.first { $0.id == "super_rosary" })
        let volley = try XCTUnwrap(storm.projectile)
        XCTAssertGreaterThanOrEqual(volley.spawnCount, 3)
        XCTAssertGreaterThanOrEqual(volley.maxOnScreen, volley.spawnCount)
        XCTAssertEqual(storm.hitstop, 10)
        RosterKitSpec.assertNotPlusOnBlock(def)
        assertAuthoredHitstop(def)
    }

    func testRookKitMatchesFixB() throws {
        let (def, raw) = try RosterKitSpec.load("rook")
        RosterKitSpec.assertIdentity(
            def,
            displayName: "Rook",
            archetype: "armor/counter",
            health: 1000,
            walkForward: 448,
            walkBack: 512
        )
        XCTAssertEqual(def.moves.count, 9)
        RosterKitSpec.assertNormalsAndThrow(raw)
        RosterKitSpec.assertSpecialNames(raw, names: ["Rocket Jab", "Guard Protocol"])
        RosterKitSpec.assertSuper(raw, name: "Overclock Barrage", button: "K")
        XCTAssertFalse(raw.contains { $0.motion == "623" })

        let jab = RosterKitSpec.rows(raw, name: "Rocket Jab")
        XCTAssertEqual(Set(jab.map(\.motion)), ["236"])
        XCTAssertEqual(Set(jab.map(\.button)), ["LP", "HP"])
        let light = try XCTUnwrap(def.moves.first { $0.id == "sp_rocket_lp" })
        let heavy = try XCTUnwrap(def.moves.first { $0.id == "sp_rocket_hp" })
        XCTAssertEqual(light.armorHits, 0)
        XCTAssertEqual(heavy.armorHits, 1)
        XCTAssertTrue(light.velocities.contains { $0.x > 0 })
        XCTAssertTrue(heavy.velocities.contains { $0.x > 0 })

        let protocolRaw = RosterKitSpec.rows(raw, name: "Guard Protocol")
        XCTAssertEqual(protocolRaw.map(\.motion), ["214"])
        XCTAssertEqual(protocolRaw.map(\.button), ["P"])
        let stance = try XCTUnwrap(def.moves.first { $0.id == "sp_guard_protocol" })
        let counter = try XCTUnwrap(stance.counter)
        XCTAssertLessThan(counter.startTick, counter.endTick)
        XCTAssertEqual(counter.followUpMoveID, "rook_norm_hp")
        XCTAssertTrue(def.moves.contains { $0.id == "rook_norm_hp" })

        let barrage = try XCTUnwrap(def.moves.first { $0.id == "super_overclock" })
        XCTAssertGreaterThanOrEqual(barrage.hits.count, 3)
        XCTAssertEqual(barrage.inputKind, .superMove)
        XCTAssertEqual(barrage.hitstop, 10)
        XCTAssertTrue(def.moves.contains { $0.id == "rook_throw_lp_lk" })
        RosterKitSpec.assertNotPlusOnBlock(def)
        assertAuthoredHitstop(def)
    }

    private func assertAuthoredHitstop(_ def: FighterDef, file: StaticString = #filePath, line: UInt = #line) {
        for move in def.moves {
            switch move.inputKind {
            case .special:
                XCTAssertTrue((8 ... 10).contains(move.hitstop), move.id, file: file, line: line)
            case .superMove:
                XCTAssertEqual(move.hitstop, 10, move.id, file: file, line: line)
            case .normal, .throwMove:
                break
            }
        }
    }
}
