public struct CollisionResolver: CollisionResolving {
    public var context: CollisionMatchContext

    public init(context: CollisionMatchContext = CollisionMatchContext()) {
        self.context = context
    }

    public mutating func resolveMovement(snapshot: inout GameSnapshot) {
        guard snapshot.rules.hitstopRemaining <= 0 else { return }
        guard snapshot.fighters.count >= 2 else { return }
        guard !context.fighterDefs.isEmpty else { return }

        clampToStage(snapshot: &snapshot)
        separatePushboxes(snapshot: &snapshot)
    }

    public mutating func resolveHits(snapshot: inout GameSnapshot) {
        guard snapshot.rules.hitstopRemaining <= 0 else { return }
        guard snapshot.fighters.count >= 2 else { return }
        guard !context.fighterDefs.isEmpty else { return }

        var pending: [HitResolution] = []
        pending.reserveCapacity(4)

        for attackerSlot in PlayerSlot.allCases {
            let aIdx = Int(attackerSlot.rawValue)
            guard aIdx < snapshot.fighters.count else { continue }
            let attacker = snapshot.fighters[aIdx]
            guard canAttackHit(attacker) else { continue }
            guard let atkDef = context.def(for: attackerSlot, snapshot: snapshot) else { continue }
            guard let move = atkDef.moves.first(where: { $0.id == attacker.activeMoveID }) else { continue }

            let activeIndex = activeFrameIndex(for: attacker, move: move)
            guard activeIndex >= 0 else { continue }

            let isThrow = move.guardLevel == .throwAttack
            let atkBoxes: [Hitbox]
            if isThrow {
                guard activeIndex < move.frames.throwBoxes.count else { continue }
                atkBoxes = [move.frames.throwBoxes[activeIndex]]
            } else {
                guard activeIndex < move.frames.hit.count else { continue }
                atkBoxes = [move.frames.hit[activeIndex]]
            }

            for defenderSlot in PlayerSlot.allCases where defenderSlot != attackerSlot {
                let dIdx = Int(defenderSlot.rawValue)
                guard dIdx < snapshot.fighters.count else { continue }
                if isThrow && !canBeThrown(snapshot.fighters[dIdx]) { continue }
                if move.guardLevel == .high,
                    snapshot.fighters[dIdx].kind == .crouch || snapshot.fighters[dIdx].kind == .blockstunCrouch
                {
                    continue
                }

                let hurtBoxes = hurtboxes(
                    for: snapshot.fighters[dIdx],
                    def: context.def(for: defenderSlot, snapshot: snapshot)
                )
                let ax = snapshot.fighters[aIdx].position.x.raw
                let ay = snapshot.fighters[aIdx].position.y.raw
                let facing = snapshot.fighters[aIdx].facingRight

                var connected = false
                for atkBox in atkBoxes {
                    let atkWorld = BoxMath.worldBox(anchorX: ax, anchorY: ay, box: atkBox, facingRight: facing)
                    for hurt in hurtBoxes {
                        let dx = snapshot.fighters[dIdx].position.x.raw
                        let dy = snapshot.fighters[dIdx].position.y.raw
                        let df = snapshot.fighters[dIdx].facingRight
                        let defWorld = BoxMath.worldBox(anchorX: dx, anchorY: dy, box: hurt, facingRight: df)
                        if atkWorld.overlaps(defWorld) {
                            connected = true
                            break
                        }
                    }
                    if connected { break }
                }
                guard connected else { continue }

                let block = !isThrow && blocks(move: move, defender: snapshot.fighters[dIdx])
                pending.append(
                    HitResolution(
                        attacker: attackerSlot,
                        defender: defenderSlot,
                        move: move,
                        blocked: block
                    )
                )
            }
        }

        resolveProjectiles(snapshot: &snapshot, pending: &pending)

        guard !pending.isEmpty else { return }

        var maxHitstop: Int32 = 0
        for hit in pending {
            applyHit(hit, snapshot: &snapshot)
            if hit.move.hitstop > maxHitstop {
                maxHitstop = hit.move.hitstop
            }
        }
        if maxHitstop > 0 {
            snapshot.rules.hitstopRemaining = max(snapshot.rules.hitstopRemaining, maxHitstop)
        }
    }
}

private struct HitResolution {
    var attacker: PlayerSlot
    var defender: PlayerSlot
    var move: MoveDef
    var blocked: Bool
}

private extension CollisionResolver {
    func clampToStage(snapshot: inout GameSnapshot) {
        let leftRaw = context.playLeftPx * BoxMath.scale
        let rightRaw = context.playRightPx * BoxMath.scale

        for i in snapshot.fighters.indices {
            guard let def = context.def(for: PlayerSlot(rawValue: UInt8(i)) ?? .p1, snapshot: snapshot) else {
                continue
            }
            let push = pushbox(for: snapshot.fighters[i], def: def)
            let mirrored = BoxMath.mirrorX(push, facingRight: snapshot.fighters[i].facingRight)
            let pos = snapshot.fighters[i].position.x.raw
            let bodyLeft = pos + mirrored.x * BoxMath.scale
            let bodyRight = bodyLeft + mirrored.w * BoxMath.scale

            var delta: Int32 = 0
            if bodyLeft < leftRaw {
                delta = leftRaw - bodyLeft
            } else if bodyRight > rightRaw {
                delta = rightRaw - bodyRight
            }
            if delta != 0 {
                snapshot.fighters[i].position.x.raw += delta
            }
            snapshot.fighters[i].position.y.raw = StageBounds.floorPx * BoxMath.scale
        }
    }

    func separatePushboxes(snapshot: inout GameSnapshot) {
        guard snapshot.fighters.count >= 2 else { return }
        let a = worldPushbox(fighter: snapshot.fighters[0], slot: .p1, snapshot: snapshot)
        let b = worldPushbox(fighter: snapshot.fighters[1], slot: .p2, snapshot: snapshot)
        let overlap = BoxMath.horizontalOverlap(a, b)
        guard overlap > 0 else { return }

        let half = overlap / 2
        let remainder = overlap % 2
        if snapshot.fighters[0].position.x.raw <= snapshot.fighters[1].position.x.raw {
            snapshot.fighters[0].position.x.raw -= half
            snapshot.fighters[1].position.x.raw += half + remainder
        } else {
            snapshot.fighters[1].position.x.raw -= half
            snapshot.fighters[0].position.x.raw += half + remainder
        }
    }

    func worldPushbox(fighter: FighterState, slot: PlayerSlot, snapshot: GameSnapshot) -> WorldBox {
        let def = context.def(for: slot, snapshot: snapshot) ?? FighterDef(
            id: "fallback",
            displayName: "fallback",
            gamePlan: "fallback"
        )
        let push = pushbox(for: fighter, def: def)
        return BoxMath.worldBox(
            anchorX: fighter.position.x.raw,
            anchorY: fighter.position.y.raw,
            box: push,
            facingRight: fighter.facingRight
        )
    }

    func pushbox(for fighter: FighterState, def: FighterDef) -> Hitbox {
        if fighter.kind == .attackActive || fighter.kind == .attackStartup || fighter.kind == .attackRecovery,
           let move = def.moves.first(where: { $0.id == fighter.activeMoveID })
        {
            let index = activeFrameIndex(for: fighter, move: move)
            if index >= 0, index < move.frames.push.count {
                return move.frames.push[index]
            }
        }
        return def.pushbox
    }

    func hurtboxes(for fighter: FighterState, def: FighterDef?) -> [Hitbox] {
        guard let def else {
            return []
        }
        if fighter.kind == .attackActive || fighter.kind == .attackStartup || fighter.kind == .attackRecovery,
           let move = def.moves.first(where: { $0.id == fighter.activeMoveID })
        {
            let index = activeFrameIndex(for: fighter, move: move)
            if index >= 0, index < move.frames.hurt.count {
                return [move.frames.hurt[index]]
            }
        }
        if let set = def.hurtboxes.first(where: { $0.state == fighter.kind }) {
            return set.boxes
        }
        return def.hurtboxes.first(where: { $0.state == .idle })?.boxes ?? []
    }

    func canAttackHit(_ fighter: FighterState) -> Bool {
        fighter.kind == .attackActive
    }

    func canBeThrown(_ fighter: FighterState) -> Bool {
        switch fighter.kind {
        case .hitstun, .blockstunStand, .blockstunCrouch, .knockdown, .beingThrown, .ko, .win:
            return false
        default:
            return true
        }
    }

    func activeFrameIndex(for fighter: FighterState, move: MoveDef) -> Int {
        let t = Int(fighter.stateTick)
        let startup = Int(move.startup)
        let active = Int(move.active)
        guard t >= startup, t < startup + active else { return -1 }
        return t - startup
    }

    enum GuardStance {
        case standing
        case crouching
    }

    func guardStance(for kind: FighterStateKind) -> GuardStance? {
        switch kind {
        case .walkBack, .blockstunStand:
            return .standing
        case .crouch, .blockstunCrouch:
            return .crouching
        default:
            return nil
        }
    }

    func blocks(move: MoveDef, defender: FighterState) -> Bool {
        guard let stance = guardStance(for: defender.kind) else { return false }
        switch move.guardLevel {
        case .high:
            return stance == .standing
        case .mid:
            return true
        case .low:
            return stance == .crouching
        case .throwAttack:
            return false
        }
    }

    func applyHit(_ hit: HitResolution, snapshot: inout GameSnapshot) {
        let aIdx = Int(hit.attacker.rawValue)
        let dIdx = Int(hit.defender.rawValue)
        var defender = snapshot.fighters[dIdx]

        let tick = snapshot.tick
        let pushbackPx = hit.blocked ? hit.move.pushbackBlock : hit.move.pushbackHit
        let sign: Int32 = snapshot.fighters[aIdx].position.x.raw < defender.position.x.raw ? 1 : -1
        defender.position.x.raw += sign * pushbackPx * BoxMath.scale

        if hit.move.guardLevel == .throwAttack {
            defender.health -= hit.move.damage
            defender.kind = .beingThrown
            defender.timer = hit.move.hitstun
            snapshot.fighters[dIdx] = defender
            snapshot.events.append(
                GameEvent(
                    kind: .throwHit,
                    tick: tick,
                    attacker: hit.attacker,
                    defender: hit.defender,
                    moveID: hit.move.id,
                    damage: hit.move.damage
                )
            )
            return
        }

        if hit.blocked {
            var chipDamage = hit.move.chip
            if hit.move.inputKind == .special || hit.move.inputKind == .superMove {
                if chipDamage == 0, hit.move.damage > 0 {
                    chipDamage = hit.move.damage / 4
                }
                if defender.health - chipDamage < 1 {
                    chipDamage = max(0, defender.health - 1)
                }
            } else {
                chipDamage = 0
            }
            defender.health -= chipDamage
            defender.kind = hit.move.guardLevel == .low ? .blockstunCrouch : .blockstunStand
            defender.timer = hit.move.blockstun
            snapshot.fighters[dIdx] = defender
            var attacker = snapshot.fighters[aIdx]
            attacker.meter = min(MatchRules.meterCap, attacker.meter + hit.move.meterGain / 2)
            snapshot.fighters[aIdx] = attacker
            snapshot.events.append(
                GameEvent(
                    kind: chipDamage > 0 ? .chip : .block,
                    tick: tick,
                    attacker: hit.attacker,
                    defender: hit.defender,
                    moveID: hit.move.id,
                    damage: chipDamage
                )
            )
            return
        }

        defender.health -= hit.move.damage
        defender.kind = .hitstun
        defender.timer = hit.move.hitstun
        let meterGainDef = hit.move.damage / 4
        defender.meter = min(MatchRules.meterCap, defender.meter + meterGainDef)
        snapshot.fighters[dIdx] = defender

        var attacker = snapshot.fighters[aIdx]
        attacker.meter = min(MatchRules.meterCap, attacker.meter + hit.move.meterGain)
        snapshot.fighters[aIdx] = attacker

        snapshot.events.append(
            GameEvent(
                kind: .hit,
                tick: tick,
                attacker: hit.attacker,
                defender: hit.defender,
                moveID: hit.move.id,
                damage: hit.move.damage
            )
        )
    }

    func resolveProjectiles(snapshot: inout GameSnapshot, pending: inout [HitResolution]) {
        for pIndex in snapshot.projectiles.indices {
            var projectile = snapshot.projectiles[pIndex]
            guard projectile.active else { continue }
            let owner = projectile.owner
            for defenderSlot in PlayerSlot.allCases where defenderSlot != owner {
                let dIdx = Int(defenderSlot.rawValue)
                guard dIdx < snapshot.fighters.count else { continue }
                let hurtBoxes = hurtboxes(
                    for: snapshot.fighters[dIdx],
                    def: context.def(for: defenderSlot, snapshot: snapshot)
                )
                let px = projectile.position.x.raw
                let py = projectile.position.y.raw
                let atkWorld = BoxMath.worldBox(
                    anchorX: px,
                    anchorY: py,
                    box: projectile.hitbox,
                    facingRight: true
                )
                for hurt in hurtBoxes {
                    let dx = snapshot.fighters[dIdx].position.x.raw
                    let dy = snapshot.fighters[dIdx].position.y.raw
                    let df = snapshot.fighters[dIdx].facingRight
                    let defWorld = BoxMath.worldBox(anchorX: dx, anchorY: dy, box: hurt, facingRight: df)
                    if atkWorld.overlaps(defWorld) {
                        projectile.active = false
                        snapshot.projectiles[pIndex] = projectile
                        let pseudoMove = MoveDef(
                            id: "projectile_\(projectile.id)",
                            name: "Projectile",
                            inputKind: .special,
                            damage: projectile.damage,
                            chip: projectile.damage / 4,
                            hitstun: 12,
                            blockstun: 8,
                            hitstop: 8,
                            guardLevel: .mid
                        )
                        pending.append(
                            HitResolution(
                                attacker: owner,
                                defender: defenderSlot,
                                move: pseudoMove,
                                blocked: blocks(move: pseudoMove, defender: snapshot.fighters[dIdx])
                            )
                        )
                        break
                    }
                }
            }
        }
    }
}

/// Backward-compatible default used by `Simulation` until match bootstrap supplies defs.
public typealias CollisionResolvingStub = CollisionResolver