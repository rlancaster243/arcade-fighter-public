import XCTest
@testable import FightCore

enum CollisionTestSupport {
    static func greyboxDef() throws -> FighterDef {
        try FighterLoader.loadFighter(from: ContentPaths.greyboxDirectory())
    }

    static func pairContext() throws -> CollisionMatchContext {
        let def = try greyboxDef()
        return CollisionMatchContext(fighterDefs: [def, def])
    }

    static func snapshot(
        p1: FighterState,
        p2: FighterState,
        tick: Int32 = 1,
        hitstop: Int32 = 0
    ) -> GameSnapshot {
        var rules = MatchRules()
        rules.hitstopRemaining = hitstop
        return GameSnapshot(
            tick: tick,
            rng: SeededRNG(seed: 1),
            fighters: [p1, p2],
            projectiles: [],
            rules: rules,
            events: [],
            fighterIDs: ["greybox", "greybox"]
        )
    }

    static func attacking(
        moveID: String,
        stateTick: Int32,
        positionX: Int32,
        facingRight: Bool
    ) -> FighterState {
        FighterState(
            kind: .attackActive,
            timer: 0,
            position: Vec2(x: Fixed(pixels: positionX), y: .zero),
            velocity: .zero,
            facingRight: facingRight,
            health: 1000,
            meter: 0,
            activeMoveID: moveID,
            stateTick: stateTick
        )
    }

    static func standing(at positionX: Int32, facingRight: Bool, kind: FighterStateKind = .idle) -> FighterState {
        FighterState(
            kind: kind,
            timer: 0,
            position: Vec2(x: Fixed(pixels: positionX), y: .zero),
            velocity: .zero,
            facingRight: facingRight,
            health: 1000,
            meter: 0,
            activeMoveID: "",
            stateTick: 0
        )
    }

    static func tinyDef(
        guardLevel: GuardLevel,
        inputKind: MoveInputKind = .normal,
        chip: Int32 = 0,
        damage: Int32 = 100
    ) -> FighterDef {
        let hit = Hitbox(x: 10, y: -50, w: 30, h: 50)
        let hurt = Hitbox(x: -15, y: -50, w: 30, h: 50)
        let pushbox = Hitbox(x: -12, y: -50, w: 24, h: 50)
        let move = MoveDef(
            id: "test_move",
            name: "Test",
            inputKind: inputKind,
            startup: 0,
            active: 1,
            recovery: 0,
            frames: MoveFrameBoxes(
                hit: [hit],
                hurt: [hurt],
                push: [pushbox],
                throwBoxes: []
            ),
            damage: damage,
            chip: chip,
            hitstun: 10,
            blockstun: 6,
            pushbackHit: 6,
            pushbackBlock: 3,
            meterGain: 100,
            hitstop: 6,
            guardLevel: guardLevel,
            unblockable: guardLevel == .throwAttack
        )
        return FighterDef(
            id: "tiny",
            displayName: "Tiny",
            gamePlan: "tests",
            pushbox: Hitbox(x: -12, y: -50, w: 24, h: 50),
            hurtboxes: [
                HurtboxSet(state: .idle, boxes: [hurt]),
                HurtboxSet(state: .crouch, boxes: [Hitbox(x: -15, y: -35, w: 30, h: 35)]),
                HurtboxSet(state: .walkBack, boxes: [hurt]),
            ],
            moves: [move]
        )
    }
}