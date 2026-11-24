import XCTest
@testable import FightCore

/// T-CORE-ADV: invulnerability, armor, projectile lifecycle, throw states.
final class TCoreAdvancedMechanicsTests: XCTestCase {
    func testT_CORE_ADV_invulnerableActiveFramesWhenHurtCleared() throws {
        let def = try greyboxWithInvulnSpecial()
        let stepper = FighterTestFixtures.stepper(with: def)
        var snap = FighterTestFixtures.baseSnapshot(def: def)

        snap.fighterIDs = [def.id, def.id]
        snap.fighters[0].kind = .attackActive
        snap.fighters[0].activeMoveID = "sp_invuln"
        snap.fighters[0].stateTick = 3

        XCTAssertTrue(stepper.isInvulnerable(fighter: snap.fighters[0], defID: def.id))

        snap.fighters[0].stateTick = 2
        XCTAssertFalse(stepper.isInvulnerable(fighter: snap.fighters[0], defID: def.id))
    }

    func testT_CORE_ADV_armorHitsOnDP() throws {
        let def = try FighterTestFixtures.greyboxDef()
        var stepper = FighterTestFixtures.stepper(with: def)
        var snap = FighterTestFixtures.baseSnapshot(def: def)

        snap.fighters[0].activeMoveID = "sp_dp"
        stepper.stepFighters(snapshot: &snap)
        XCTAssertEqual(stepper.armorHitsRemaining(slot: .p1), 1)
        XCTAssertTrue(stepper.consumeArmorHit(slot: .p1, snapshot: &snap))
        XCTAssertEqual(snap.fighters[0].armorRemaining, 0)
        XCTAssertEqual(stepper.armorHitsRemaining(slot: .p1), 0)
    }

    func testT_CORE_ADV_projectileSpawnAndLifetime() throws {
        let def = try FighterTestFixtures.greyboxDef()
        var stepper = FighterTestFixtures.stepper(with: def)
        var snap = FighterTestFixtures.baseSnapshot(def: def)

        let move = FighterTestFixtures.move("sp_qcf", in: def)
        snap.fighters[0].activeMoveID = "sp_qcf"
        stepper.stepFighters(snapshot: &snap)

        for _ in 0..<move.startup {
            stepper.stepFighters(snapshot: &snap)
        }
        XCTAssertEqual(snap.projectiles.count, 1)
        let spawnedID = snap.projectiles[0].id

        for _ in 0..<95 {
            stepper.stepFighters(snapshot: &snap)
        }
        XCTAssertTrue(snap.projectiles.isEmpty || !snap.projectiles.contains { $0.id == spawnedID && $0.active })
    }

    func testT_CORE_ADV_throwConnectAndThrowingStates() throws {
        let def = try FighterTestFixtures.greyboxDef()
        let throwMove = FighterTestFixtures.move("throw_lp_lk", in: def)
        var stepper = FighterTestFixtures.stepper(with: def)
        var snap = FighterTestFixtures.baseSnapshot(def: def)

        snap.fighters[0].activeMoveID = "throw_lp_lk"
        stepper.stepFighters(snapshot: &snap)

        for _ in 0..<throwMove.startup {
            stepper.stepFighters(snapshot: &snap)
        }
        XCTAssertEqual(snap.fighters[0].kind, .throwing)
        XCTAssertEqual(snap.fighters[1].kind, .beingThrown)
        XCTAssertTrue(snap.events.contains { $0.kind == .throwHit })
    }

    func testT_CORE_ADV_throwTechKeepsDefenderNeutral() throws {
        let def = try FighterTestFixtures.greyboxDef()
        let throwMove = FighterTestFixtures.move("throw_lp_lk", in: def)
        var stepper = FighterTestFixtures.stepper(with: def)
        var snap = FighterTestFixtures.baseSnapshot(def: def)

        snap.fighters[0].activeMoveID = "throw_lp_lk"
        stepper.stepFighters(snapshot: &snap)

        let preActiveTicks = max(0, throwMove.startup - 1)
        for _ in 0..<preActiveTicks {
            stepper.stepFighters(snapshot: &snap)
        }

        snap.fighters[1].activeMoveID = "throw_lp_lk"
        stepper.stepFighters(snapshot: &snap)

        XCTAssertEqual(snap.fighters[1].kind, .idle)
        XCTAssertNotEqual(snap.fighters[0].kind, .throwing)
    }

    /// A throw with several active frames used to grab on the frame after it was teched.
    func testATechedThrowDoesNotGrabAgainOnALaterActiveFrame() throws {
        var def = try FighterTestFixtures.greyboxDef()
        let index = try XCTUnwrap(def.moves.firstIndex { $0.id == "throw_lp_lk" })
        def.moves[index].active = 4
        let throwMove = def.moves[index]
        var stepper = FighterTestFixtures.stepper(with: def)
        var snap = FighterTestFixtures.baseSnapshot(def: def)

        snap.fighters[0].activeMoveID = "throw_lp_lk"
        stepper.stepFighters(snapshot: &snap)
        for _ in 0..<max(0, throwMove.startup - 1) {
            stepper.stepFighters(snapshot: &snap)
        }
        snap.fighters[1].activeMoveID = "throw_lp_lk"
        stepper.stepFighters(snapshot: &snap) // the tech
        snap.fighters[1].activeMoveID = ""
        snap.fighters[1].kind = .idle

        for _ in 0..<6 {
            stepper.stepFighters(snapshot: &snap)
            XCTAssertNotEqual(snap.fighters[1].kind, .beingThrown)
        }
        XCTAssertFalse(snap.events.contains { $0.kind == .throwHit })
    }

    private func greyboxWithInvulnSpecial() throws -> FighterDef {
        var def = try FighterTestFixtures.greyboxDef()
        var move = FighterTestFixtures.move("sp_qcb", in: def)
        move.id = "sp_invuln"
        move.startup = 2
        move.active = 2
        move.recovery = 2
        move.frames = MoveFrameBoxes(
            hit: [Hitbox(x: 10, y: -40, w: 20, h: 20), Hitbox(x: 10, y: -40, w: 20, h: 20)],
            hurt: [Hitbox(x: -10, y: -80, w: 30, h: 80), Hitbox(x: 0, y: 0, w: 0, h: 0)],
            push: [Hitbox(x: -20, y: -90, w: 40, h: 90), Hitbox(x: -20, y: -90, w: 40, h: 90)],
            throwBoxes: []
        )
        def.moves.append(move)
        return def
    }
}