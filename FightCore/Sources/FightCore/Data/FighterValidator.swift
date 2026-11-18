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
        if fighter.walkForward < 0 || fighter.walkBack < 0 {
            throw FighterLoadError.negativeWalkSpeed
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

            let armorHits = move.armorHits ?? 0
            if armorHits < 0 {
                throw FighterLoadError.negativeArmorHits(move.id)
            }
            let whiffsVsAirborne = move.whiffsVsAirborne ?? false
            if whiffsVsAirborne && guardLevel != .throwAttack {
                throw FighterLoadError.whiffsVsAirborneNonThrow(move.id)
            }
            let projectile = try validateProjectile(move)
            let velocities = try validateVelocities(move)
            let invulnerableFrames = try validateInvulnerableFrames(move)
            let hits = try validateHits(move)
            let counter = try validateCounterWindow(move)

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
                    unblockable: unblockable,
                    armorHits: armorHits,
                    projectile: projectile,
                    velocities: velocities,
                    invulnerableFrames: invulnerableFrames,
                    whiffsVsAirborne: whiffsVsAirborne,
                    counter: counter,
                    hits: hits
                )
            )
        }

        let moveIDs = Set(moves.map(\.id))
        for move in moves {
            if let counter = move.counter, !moveIDs.contains(counter.followUpMoveID) {
                throw FighterLoadError.missingCounterFollowUp(move.id)
            }
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

    private static func validateProjectile(_ move: FighterJSON.MoveJSON) throws -> ProjectileSpawn? {
        guard let projectile = move.projectile else { return nil }
        if projectile.lifetime <= 0 {
            throw FighterLoadError.invalidProjectileLifetime(move.id)
        }
        if projectile.spawnCount <= 0 || projectile.spawnCount > move.active {
            throw FighterLoadError.invalidProjectileSpawnCount(move.id)
        }
        if projectile.maxOnScreen <= 0 {
            throw FighterLoadError.invalidProjectileMaxOnScreen(move.id)
        }
        if projectile.damage < 0 {
            throw FighterLoadError.invalidProjectileDamage(move.id)
        }
        if projectile.hitbox.w <= 0 || projectile.hitbox.h <= 0 {
            throw FighterLoadError.invalidProjectileHitbox(move.id)
        }
        return ProjectileSpawn(
            speed: projectile.speed,
            lifetime: projectile.lifetime,
            hitbox: mapBox(projectile.hitbox),
            damage: projectile.damage,
            maxOnScreen: projectile.maxOnScreen,
            spawnCount: projectile.spawnCount,
            hitsAirborne: projectile.hitsAirborne
        )
    }

    private static func validateVelocities(_ move: FighterJSON.MoveJSON) throws -> [FrameVelocity] {
        let samples = move.velocities ?? []
        if samples.isEmpty { return [] }
        let total = move.startup + move.active + move.recovery
        if Int32(samples.count) != total {
            throw FighterLoadError.velocityFrameCount(move.id)
        }
        return samples.map { FrameVelocity(x: $0.x, y: $0.y) }
    }

    private static func validateInvulnerableFrames(_ move: FighterJSON.MoveJSON) throws -> [Int32] {
        let frames = move.invulnerableFrames ?? []
        let total = move.startup + move.active + move.recovery
        var seen: Set<Int32> = []
        for frame in frames {
            if frame < 0 || frame >= total || !seen.insert(frame).inserted {
                throw FighterLoadError.invalidInvulnerableFrame(move.id)
            }
        }
        return frames
    }

    private static func validateCounterWindow(_ move: FighterJSON.MoveJSON) throws -> CounterWindow? {
        guard let counter = move.counter else { return nil }
        let total = move.startup + move.active + move.recovery
        if counter.startTick < 0 || counter.endTick <= counter.startTick || counter.endTick > total {
            throw FighterLoadError.invalidCounterWindow(move.id)
        }
        if counter.followUpMoveID.isEmpty {
            throw FighterLoadError.missingCounterFollowUp(move.id)
        }
        return CounterWindow(
            startTick: counter.startTick,
            endTick: counter.endTick,
            followUpMoveID: counter.followUpMoveID
        )
    }

    private static func validateHits(_ move: FighterJSON.MoveJSON) throws -> [MoveHit] {
        let hits = move.hits ?? []
        var seen: Set<Int32> = []
        for hit in hits {
            if hit.activeFrame < 0 || hit.activeFrame >= move.active || !seen.insert(hit.activeFrame).inserted {
                throw FighterLoadError.invalidMultiHit(move.id)
            }
            if hit.damage < 0 || hit.hitstun < 0 || hit.blockstun < 0 || hit.hitstop < 0 {
                throw FighterLoadError.invalidMultiHit(move.id)
            }
        }
        return hits.map {
            MoveHit(
                activeFrame: $0.activeFrame,
                damage: $0.damage,
                hitstun: $0.hitstun,
                blockstun: $0.blockstun,
                hitstop: $0.hitstop
            )
        }
    }

}