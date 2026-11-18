import Foundation

enum FighterValidator {
    static func validate(
        fighter: FighterJSON,
        sheet: [SheetFrameJSON],
        fighterDirectory: URL
    ) throws -> FighterDef {
        guard fighter.schemaVersion == 1 else {
            throw FighterLoadError.wrongSchemaVersion(fighter.schemaVersion)
        }
        guard !fighter.gamePlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FighterLoadError.emptyGamePlan
        }

        let sheetNames = Set(sheet.map(\.name))

        var seenMoveIDs: Set<String> = []
        var moves: [MoveDef] = []

        for move in fighter.moves {
            if seenMoveIDs.contains(move.id) {
                throw FighterLoadError.duplicateMoveID(move.id)
            }
            seenMoveIDs.insert(move.id)

            if move.startup < 0 || move.active < 0 || move.recovery < 0 {
                throw FighterLoadError.negativeFrameCount(move.id)
            }

            let guardLevel = try parseGuard(move.guardKind)
            let unblockable = move.unblockable ?? false
            if unblockable && guardLevel != .throwAttack {
                throw FighterLoadError.unblockableNonThrow(move.id)
            }

            try validateBoxCount(move.frames.hit ?? [], expected: move.active, moveID: move.id, phase: "hit")
            try validateBoxCount(move.frames.hurt ?? [], expected: move.active, moveID: move.id, phase: "hurt")
            try validateBoxCount(move.frames.push ?? [], expected: move.active, moveID: move.id, phase: "push")
            if guardLevel == .throwAttack {
                try validateBoxCount(
                    move.frames.throw ?? [],
                    expected: move.active,
                    moveID: move.id,
                    phase: "throw"
                )
            }

            let frames = MoveFrameBoxes(
                hit: (move.frames.hit ?? []).map(mapBox),
                hurt: (move.frames.hurt ?? []).map(mapBox),
                push: (move.frames.push ?? []).map(mapBox),
                throwBoxes: (move.frames.throw ?? []).map(mapBox)
            )

            moves.append(
                MoveDef(
                    id: move.id,
                    name: move.name,
                    inputKind: classifyMoveInput(move.input),
                    startup: move.startup,
                    active: move.active,
                    recovery: move.recovery,
                    frames: frames,
                    damage: move.damage,
                    chip: move.chip,
                    hitstun: move.hitstun,
                    blockstun: move.blockstun,
                    pushbackHit: move.pushbackHit,
                    pushbackBlock: move.pushbackBlock,
                    meterGain: move.meterGain,
                    hitstop: move.hitstop,
                    guardLevel: guardLevel,
                    unblockable: unblockable
                )
            )
        }

        let spritePath = fighterDirectory.appendingPathComponent(fighter.spriteSheet)
        guard FileManager.default.fileExists(atPath: spritePath.path) else {
            throw FighterLoadError.fileNotFound(fighter.spriteSheet)
        }

        var hurtboxes: [HurtboxSet] = []
        for hb in fighter.hurtboxes {
            let kind = try parseStateKind(hb.state)
            hurtboxes.append(HurtboxSet(state: kind, boxes: hb.boxes.map(mapBox)))
        }

        _ = sheetNames

        return FighterDef(
            schemaVersion: Int32(fighter.schemaVersion),
            id: fighter.id,
            displayName: fighter.displayName,
            archetype: fighter.archetype,
            gamePlan: fighter.gamePlan,
            health: fighter.health,
            walkForward: fighter.walkForward,
            walkBack: fighter.walkBack,
            jumpVelocityY: fighter.jump.velocityY,
            gravity: fighter.jump.gravity,
            pushbox: mapBox(fighter.pushbox),
            hurtboxes: hurtboxes,
            spriteSheetPath: fighter.spriteSheet,
            moves: moves
        )
    }

    private static func validateBoxCount(
        _ boxes: [FighterJSON.BoxJSON],
        expected: Int32,
        moveID: String,
        phase: String
    ) throws {
        if expected == 0 && boxes.isEmpty { return }
        if Int32(boxes.count) != expected {
            throw FighterLoadError.frameBoxCountMismatch("\(moveID).\(phase)")
        }
    }

}