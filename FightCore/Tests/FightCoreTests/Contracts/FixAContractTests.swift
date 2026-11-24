import XCTest
@testable import FightCore

/// FIX-A: whiff, time-over hash inputs, and data-driven armor / projectile / counter / command grab.
final class FixAContractTests: XCTestCase {
    func testWhiffRawValueAppendedAfterTimeOver() {
        XCTAssertEqual(GameEventKind.timeOver.rawValue, 9)
        XCTAssertEqual(GameEventKind.whiff.rawValue, 10)
    }

    func testStateHashIncludesFighterStartHealth() {
        let baseline = SimulationBootstrap.greyboxMatch()
        var other = baseline
        other.fighterStartHealth = [900, 1100]
        XCTAssertNotEqual(baseline.stateHash(), other.stateHash())
    }

    func testGreyboxWalkSpeedsAreQ8AndMoveThreePixels() throws {
        let def = try FighterTestFixtures.greyboxDef()
        XCTAssertEqual(def.walkForward, 3 * Fixed.scale)
        XCTAssertEqual(def.walkBack, 2 * Fixed.scale)
        var stepper = FighterTestFixtures.stepper(with: def)
        var snap = FighterTestFixtures.baseSnapshot(def: def)
        snap.fighters[0].kind = .walkForward
        snap.fighters[0].facingRight = true
        let start = snap.fighters[0].position.x.raw
        stepper.stepFighters(snapshot: &snap)
        XCTAssertEqual(snap.fighters[0].position.x.raw - start, 3 * Fixed.scale)
    }

    func testGreyboxArmorAndProjectileComeFromData() throws {
        let def = try FighterTestFixtures.greyboxDef()
        let dp = FighterTestFixtures.move("sp_dp", in: def)
        let qcf = FighterTestFixtures.move("sp_qcf", in: def)
        let lp = FighterTestFixtures.move("norm_lp", in: def)
        XCTAssertEqual(dp.armorHits, 1)
        XCTAssertEqual(lp.armorHits, 0)
        XCTAssertNil(lp.projectile)
        let spawn = try XCTUnwrap(qcf.projectile)
        XCTAssertEqual(spawn.speed, 6 * Fixed.scale)
        XCTAssertEqual(spawn.lifetime, 90)
        XCTAssertEqual(spawn.damage, qcf.damage)
        XCTAssertEqual(spawn.maxOnScreen, 99)
        XCTAssertEqual(spawn.spawnCount, 1)
        XCTAssertTrue(spawn.hitsAirborne)
        XCTAssertEqual(spawn.hitbox, qcf.frames.hit[0])
    }

    func testWhiffFiresOnceOnWhiffedNormal() throws {
        let totals = try attackEvents(separate: true, defenderKind: .idle)
        XCTAssertEqual(totals.whiff, 1)
        XCTAssertEqual(totals.hit, 0)
        XCTAssertEqual(totals.block, 0)
    }

    func testWhiffDoesNotFireOnHit() throws {
        let totals = try attackEvents(separate: false, defenderKind: .idle)
        XCTAssertEqual(totals.whiff, 0)
        XCTAssertGreaterThan(totals.hit, 0)
    }

    func testWhiffDoesNotFireOnBlock() throws {
        let totals = try attackEvents(separate: false, defenderKind: .walkBack)
        XCTAssertEqual(totals.whiff, 0)
        XCTAssertGreaterThan(totals.block, 0)
        XCTAssertEqual(totals.hit, 0)
    }

    func testArmorIsDataNotMoveID() throws {
        var ignored = MoveDef(id: "sp_dp", name: "Named DP", armorHits: 0)
        XCTAssertEqual(MovePhaseMath.armorHits(for: ignored), 0)
        ignored.id = "shell"
        ignored.armorHits = 2
        XCTAssertEqual(MovePhaseMath.armorHits(for: ignored), 2)

        var def = try FighterTestFixtures.greyboxDef()
        var shell = FighterTestFixtures.move("norm_lp", in: def)
        shell.id = "shell"
        shell.name = "Shell"
        shell.armorHits = 1
        def.moves.append(shell)
        var dp = FighterTestFixtures.move("sp_dp", in: def)
        dp.armorHits = 0
        def.moves.removeAll { $0.id == "sp_dp" }
        def.moves.append(dp)

        var stepper = FighterTestFixtures.stepper(with: def)
        var snap = FighterTestFixtures.baseSnapshot(def: def)
        snap.fighters[0].activeMoveID = "shell"
        stepper.stepFighters(snapshot: &snap)
        XCTAssertEqual(stepper.armorHitsRemaining(slot: .p1), 1)

        snap.fighters[0].kind = .idle
        snap.fighters[0].activeMoveID = "sp_dp"
        snap.fighters[0].stateTick = 0
        stepper.stepFighters(snapshot: &snap)
        XCTAssertEqual(stepper.armorHitsRemaining(slot: .p1), 0)
    }

    func testArmorAbsorbSuppressesWhiff() throws {
        let def = try FighterTestFixtures.greyboxDef()
        let lp = FighterTestFixtures.move("norm_lp", in: def)
        var stepper = FighterTestFixtures.stepper(with: def)
        var collision = CollisionResolver(context: CollisionMatchContext(fighterDefs: [def, def]))
        var snap = FighterTestFixtures.baseSnapshot(def: def)
        snap.fighters[0].position = Vec2(x: .zero, y: .zero)
        snap.fighters[1].position = Vec2(x: Fixed(pixels: 8), y: .zero)
        snap.fighters[1].armorRemaining = 4
        snap.fighters[0].activeMoveID = "norm_lp"

        var whiffs = 0
        let steps = lp.startup + lp.active + lp.recovery + 3
        for _ in 0..<steps {
            snap.events.removeAll()
            stepper.stepFighters(snapshot: &snap)
            collision.resolveHits(snapshot: &snap)
            whiffs += snap.events.filter { $0.kind == .whiff && $0.moveID == "norm_lp" }.count
        }
        XCTAssertEqual(whiffs, 0)
        XCTAssertEqual(snap.fighters[1].health, 1000)
        XCTAssertLessThan(snap.fighters[1].armorRemaining, 4)
    }

    func testProjectileSpawnIsDataNotMoveID() {
        var named = MoveDef(id: "sp_qcf", name: "Named", startup: 2, active: 3)
        XCTAssertFalse(ProjectileLogic.moveSpawnsProjectile(move: named, stateTick: 2))
        named.id = "bead_shot"
        XCTAssertFalse(ProjectileLogic.moveSpawnsProjectile(move: named, stateTick: 2))
        named.projectile = ProjectileSpawn(
            speed: 512,
            lifetime: 20,
            hitbox: Hitbox(x: 0, y: -20, w: 10, h: 10),
            damage: 12,
            maxOnScreen: 2,
            spawnCount: 2,
            hitsAirborne: false
        )
        XCTAssertFalse(ProjectileLogic.moveSpawnsProjectile(move: named, stateTick: 1))
        XCTAssertTrue(ProjectileLogic.moveSpawnsProjectile(move: named, stateTick: 2))
        XCTAssertTrue(ProjectileLogic.moveSpawnsProjectile(move: named, stateTick: 3))
        XCTAssertFalse(ProjectileLogic.moveSpawnsProjectile(move: named, stateTick: 4))
    }

    func testProjectileHitsAirborneFlagIsData() throws {
        let def = try FighterTestFixtures.greyboxDef()
        let ctx = CollisionMatchContext(fighterDefs: [def, def])
        var resolver = CollisionResolver(context: ctx)
        var grounded = projectileSnapshot(def: def, hitsAirborne: false, defenderKind: .idle)
        resolver.resolveHits(snapshot: &grounded)
        XCTAssertLessThan(grounded.fighters[1].health, 1000)

        var airborne = projectileSnapshot(def: def, hitsAirborne: false, defenderKind: .airborne)
        resolver.resolveHits(snapshot: &airborne)
        XCTAssertEqual(airborne.fighters[1].health, 1000)
        XCTAssertTrue(airborne.events.isEmpty)

        var airborneHit = projectileSnapshot(def: def, hitsAirborne: true, defenderKind: .airborne)
        resolver.resolveHits(snapshot: &airborneHit)
        XCTAssertLessThan(airborneHit.fighters[1].health, 1000)
    }

    /// A real projectile hit must leave its owner's strike unspent, or the follow-up attack
    /// would pass straight through.
    func testProjectileHitDoesNotSpendTheOwnersStrike() throws {
        let def = try FighterTestFixtures.greyboxDef()
        var resolver = CollisionResolver(context: CollisionMatchContext(fighterDefs: [def, def]))
        var snap = projectileSnapshot(def: def, hitsAirborne: false, defenderKind: .idle)
        resolver.resolveHits(snapshot: &snap)
        XCTAssertLessThan(snap.fighters[1].health, 1000)
        XCTAssertFalse(snap.fighters[0].strikeSpent)
    }

    func testCounterIsDataNotMoveID() throws {
        let countered = try counterSnapshot(stanceID: "stance", withCounter: true)
        var resolver = CollisionResolver(context: countered.context)
        var snap = countered.snapshot
        resolver.resolveHits(snapshot: &snap)
        XCTAssertEqual(snap.fighters[1].health, 1000)
        XCTAssertEqual(snap.fighters[0].health, 960)
        XCTAssertTrue(snap.events.contains { $0.kind == .hit && $0.moveID == "reply" && $0.attacker == .p2 })
        XCTAssertEqual(snap.fighters[1].activeMoveID, "reply")
        XCTAssertEqual(snap.fighters[1].executingMoveID, "reply")

        var stepper = FighterStepper()
        stepper.registerDefinition(countered.context.fighterDefs[0])
        stepper.stepFighters(snapshot: &snap)
        XCTAssertEqual(snap.fighters[1].activeMoveID, "reply")
        XCTAssertEqual(snap.fighters[1].executingMoveID, "reply")

        let namedOnly = try counterSnapshot(stanceID: "guard_protocol", withCounter: false)
        var plain = CollisionResolver(context: namedOnly.context)
        var plainSnap = namedOnly.snapshot
        plain.resolveHits(snapshot: &plainSnap)
        XCTAssertEqual(plainSnap.fighters[1].health, 930)
        XCTAssertFalse(plainSnap.events.contains { $0.moveID == "reply" })
    }

    func testCommandGrabWhiffsVsAirborneFromDataNotID() throws {
        let grab = try grabSnapshot(moveID: "lift", whiffsVsAirborne: true, defenderKind: .airborne)
        var resolver = CollisionResolver(context: grab.context)
        var snap = grab.snapshot
        resolver.resolveHits(snapshot: &snap)
        XCTAssertTrue(snap.events.isEmpty)
        XCTAssertEqual(snap.fighters[1].health, 1000)

        let grounded = try grabSnapshot(moveID: "lift", whiffsVsAirborne: true, defenderKind: .idle)
        var groundedResolver = CollisionResolver(context: grounded.context)
        var groundedSnap = grounded.snapshot
        groundedResolver.resolveHits(snapshot: &groundedSnap)
        XCTAssertTrue(groundedSnap.events.contains { $0.kind == .throwHit && $0.moveID == "lift" })

        let named = try grabSnapshot(moveID: "bellows_lift", whiffsVsAirborne: false, defenderKind: .airborne)
        var namedResolver = CollisionResolver(context: named.context)
        var namedSnap = named.snapshot
        namedResolver.resolveHits(snapshot: &namedSnap)
        XCTAssertTrue(namedSnap.events.contains { $0.kind == .throwHit && $0.moveID == "bellows_lift" })
    }

    func testProjectileHonorsArmorAndInvulnerableFrames() throws {
        let body = Hitbox(x: -40, y: -90, w: 80, h: 90)
        let shell = MoveDef(
            id: "shell",
            name: "Shell",
            startup: 1,
            active: 4,
            recovery: 2,
            frames: MoveFrameBoxes(hit: [body], hurt: [body], push: [body], throwBoxes: []),
            armorHits: 1,
            invulnerableFrames: [0]
        )
        let def = FighterDef(
            id: "sheller",
            displayName: "Shell",
            gamePlan: "contract",
            pushbox: body,
            hurtboxes: [HurtboxSet(state: .idle, boxes: [body])],
            moves: [shell]
        )
        let ctx = CollisionMatchContext(fighterDefs: [def, def])
        var armored = projectileSnapshot(def: def, hitsAirborne: true, defenderKind: .idle)
        armored.fighters[1].armorRemaining = 1
        var resolver = CollisionResolver(context: ctx)
        resolver.resolveHits(snapshot: &armored)
        XCTAssertEqual(armored.fighters[1].health, 1000)
        XCTAssertEqual(armored.fighters[1].armorRemaining, 0)
        XCTAssertTrue(armored.projectiles.isEmpty || armored.projectiles.allSatisfy { !$0.active })

        var invuln = projectileSnapshot(def: def, hitsAirborne: true, defenderKind: .attackActive)
        invuln.fighters[1].activeMoveID = "shell"
        invuln.fighters[1].executingMoveID = "shell"
        invuln.fighters[1].stateTick = 0
        resolver.resolveHits(snapshot: &invuln)
        XCTAssertEqual(invuln.fighters[1].health, 1000)
        XCTAssertEqual(invuln.projectiles.first?.active, true)
    }

    func testPerFrameVelocityAndInvulnerableFramesAndMultiHitUseData() throws {
        let hit = Hitbox(x: 0, y: -40, w: 40, h: 40)
        let hurt = Hitbox(x: -20, y: -80, w: 40, h: 80)
        var dash = MoveDef(
            id: "dash",
            name: "Dash",
            startup: 1,
            active: 1,
            recovery: 1,
            frames: MoveFrameBoxes(hit: [hit], hurt: [hurt], push: [hurt], throwBoxes: []),
            damage: 10,
            velocities: [
                FrameVelocity(x: Fixed.scale, y: 0),
                FrameVelocity(x: 2 * Fixed.scale, y: 0),
                FrameVelocity(x: 0, y: 0),
            ],
            invulnerableFrames: [0]
        )
        dash.hits = [MoveHit(activeFrame: 0, damage: 17, hitstun: 6, blockstun: 4, hitstop: 6)]
        var def = FighterDef(id: "mover", displayName: "Mover", gamePlan: "contract", moves: [dash])
        def.hurtboxes = [HurtboxSet(state: .idle, boxes: [hurt])]
        var stepper = FighterStepper()
        stepper.registerDefinition(def)
        var snap = SimulationBootstrap.greyboxMatch(seed: 1)
        snap.fighterIDs = [def.id, def.id]
        snap.fighters[0].position = .zero
        snap.fighters[0].activeMoveID = "dash"
        snap.fighters[1].position = Vec2(x: Fixed(pixels: 8), y: .zero)
        let startX = snap.fighters[0].position.x.raw
        stepper.stepFighters(snapshot: &snap)
        XCTAssertEqual(snap.fighters[0].kind, .attackStartup)
        XCTAssertEqual(snap.fighters[0].stateTick, 0)
        XCTAssertEqual(snap.fighters[0].position.x.raw - startX, Fixed.scale)
        XCTAssertTrue(stepper.isInvulnerable(fighter: snap.fighters[0], defID: def.id))

        stepper.stepFighters(snapshot: &snap)
        XCTAssertEqual(snap.fighters[0].stateTick, 1)
        XCTAssertEqual(snap.fighters[0].kind, .attackActive)
        var collision = CollisionResolver(context: CollisionMatchContext(fighterDefs: [def, def]))
        collision.resolveHits(snapshot: &snap)
        XCTAssertEqual(snap.fighters[1].health, 983)
    }

    private struct AttackTotals {
        var whiff = 0
        var hit = 0
        var block = 0
    }

    private func attackEvents(separate: Bool, defenderKind: FighterStateKind) throws -> AttackTotals {
        let def = try FighterTestFixtures.greyboxDef()
        let lp = FighterTestFixtures.move("norm_lp", in: def)
        var stepper = FighterTestFixtures.stepper(with: def)
        var collision = CollisionResolver(context: CollisionMatchContext(fighterDefs: [def, def]))
        var snap = FighterTestFixtures.baseSnapshot(def: def)
        snap.fighters[0].position = Vec2(x: .zero, y: .zero)
        let defenderX: Int32 = separate ? 400 : 8
        snap.fighters[1].position = Vec2(x: Fixed(pixels: defenderX), y: .zero)
        snap.fighters[1].kind = defenderKind
        snap.fighters[1].facingRight = false
        snap.fighters[0].activeMoveID = "norm_lp"

        var totals = AttackTotals()
        let steps = lp.startup + lp.active + lp.recovery + 3
        for _ in 0..<steps {
            snap.events.removeAll()
            stepper.stepFighters(snapshot: &snap)
            collision.resolveHits(snapshot: &snap)
            totals.whiff += snap.events.filter { $0.kind == .whiff }.count
            totals.hit += snap.events.filter { $0.kind == .hit }.count
            totals.block += snap.events.filter { $0.kind == .block || $0.kind == .chip }.count
        }
        return totals
    }

    private func projectileSnapshot(
        def: FighterDef,
        hitsAirborne: Bool,
        defenderKind: FighterStateKind
    ) -> GameSnapshot {
        var snap = FighterTestFixtures.baseSnapshot(def: def)
        snap.fighters[1].kind = defenderKind
        snap.fighters[1].position = Vec2(x: Fixed(pixels: 40), y: .zero)
        snap.projectiles = [
            Projectile(
                id: 1,
                owner: .p1,
                position: Vec2(x: Fixed(pixels: 40), y: .zero),
                velocity: .zero,
                hitbox: Hitbox(x: -30, y: -90, w: 60, h: 90),
                damage: 25,
                lifetimeTicks: 10,
                hitsAirborne: hitsAirborne
            )
        ]
        return snap
    }

    private struct Armed {
        var context: CollisionMatchContext
        var snapshot: GameSnapshot
    }

    private func counterSnapshot(stanceID: String, withCounter: Bool) throws -> Armed {
        let body = Hitbox(x: -30, y: -80, w: 60, h: 80)
        let strike = MoveDef(
            id: "jab",
            name: "Jab",
            startup: 1,
            active: 1,
            recovery: 1,
            frames: MoveFrameBoxes(hit: [body], hurt: [body], push: [body], throwBoxes: []),
            damage: 70,
            hitstun: 8,
            blockstun: 6,
            hitstop: 6
        )
        var stance = MoveDef(
            id: stanceID,
            name: "Stance",
            startup: 1,
            active: 6,
            recovery: 4,
            frames: MoveFrameBoxes(hit: [body], hurt: [body], push: [body], throwBoxes: []),
            damage: 0
        )
        if withCounter {
            stance.counter = CounterWindow(startTick: 0, endTick: 10, followUpMoveID: "reply")
        }
        let reply = MoveDef(
            id: "reply",
            name: "Reply",
            startup: 1,
            active: 1,
            recovery: 2,
            frames: MoveFrameBoxes(hit: [body], hurt: [body], push: [body], throwBoxes: []),
            damage: 40,
            hitstun: 8,
            blockstun: 6,
            hitstop: 6
        )
        let def = FighterDef(
            id: "counter",
            displayName: "Counter",
            gamePlan: "contract",
            pushbox: body,
            hurtboxes: [HurtboxSet(state: .idle, boxes: [body])],
            moves: [strike, stance, reply]
        )
        var snap = SimulationBootstrap.greyboxMatch(seed: 1)
        snap.fighterIDs = [def.id, def.id]
        snap.fighters[0] = FighterState(
            kind: .attackActive,
            position: Vec2(x: .zero, y: .zero),
            facingRight: true,
            activeMoveID: "jab",
            stateTick: 1
        )
        snap.fighters[1] = FighterState(
            kind: .attackActive,
            position: Vec2(x: Fixed(pixels: 8), y: .zero),
            facingRight: false,
            activeMoveID: stanceID,
            stateTick: 1
        )
        return Armed(context: CollisionMatchContext(fighterDefs: [def, def]), snapshot: snap)
    }

    private func grabSnapshot(moveID: String, whiffsVsAirborne: Bool, defenderKind: FighterStateKind) throws -> Armed {
        let body = Hitbox(x: -30, y: -80, w: 60, h: 80)
        let grab = MoveDef(
            id: moveID,
            name: "Grab",
            inputKind: .special,
            startup: 1,
            active: 1,
            recovery: 8,
            frames: MoveFrameBoxes(hit: [], hurt: [body], push: [body], throwBoxes: [body]),
            damage: 120,
            hitstun: 12,
            guardLevel: .throwAttack,
            unblockable: true,
            whiffsVsAirborne: whiffsVsAirborne
        )
        let def = FighterDef(
            id: "grabber",
            displayName: "Grabber",
            gamePlan: "contract",
            pushbox: body,
            hurtboxes: [
                HurtboxSet(state: .idle, boxes: [body]),
                HurtboxSet(state: .airborne, boxes: [body]),
            ],
            moves: [grab]
        )
        var snap = SimulationBootstrap.greyboxMatch(seed: 1)
        snap.fighterIDs = [def.id, def.id]
        snap.fighters[0] = FighterState(
            kind: .attackActive,
            position: Vec2(x: .zero, y: .zero),
            facingRight: true,
            activeMoveID: moveID,
            stateTick: 1
        )
        snap.fighters[1] = FighterState(
            kind: defenderKind,
            position: Vec2(x: Fixed(pixels: 8), y: .zero),
            facingRight: false,
            health: 1000
        )
        return Armed(context: CollisionMatchContext(fighterDefs: [def, def]), snapshot: snap)
    }
}
