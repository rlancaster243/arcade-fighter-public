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

            // One attack, one hit. A move without per-frame `hits` specs used to connect again on
            // every active frame (a 108-damage heavy dealt 324), so rounds ended in a few blows.
            // Multi-hit moves list their hits explicitly and are not limited here. This reads
            // `strikeSpent`, not `attackContact`: the fighter's own projectile making contact
            // must not swallow the strike. Armor absorbing the strike itself does spend it.
            if move.hits.isEmpty, attacker.strikeSpent { continue }

            let activeIndex = activeFrameIndex(for: attacker, move: move)
            guard activeIndex >= 0 else { continue }

            var resolvedMove = move
            if !move.hits.isEmpty {
                guard let spec = move.hits.first(where: { $0.activeFrame == Int32(activeIndex) }) else {
                    continue
                }
                resolvedMove.damage = spec.damage
                resolvedMove.hitstun = spec.hitstun
                resolvedMove.blockstun = spec.blockstun
                resolvedMove.hitstop = spec.hitstop
            }

            let isThrow = resolvedMove.guardLevel == .throwAttack
            let atkBoxes: [Hitbox]
            if isThrow {
                guard activeIndex < resolvedMove.frames.throwBoxes.count else { continue }
                atkBoxes = [resolvedMove.frames.throwBoxes[activeIndex]]
            } else {
                guard activeIndex < resolvedMove.frames.hit.count else { continue }
                atkBoxes = [resolvedMove.frames.hit[activeIndex]]
            }

            for defenderSlot in PlayerSlot.allCases where defenderSlot != attackerSlot {
                let dIdx = Int(defenderSlot.rawValue)
                guard dIdx < snapshot.fighters.count else { continue }
                if resolvedMove.whiffsVsAirborne, snapshot.fighters[dIdx].kind == .airborne {
                    continue
                }
                if dataInvulnerable(
                    snapshot.fighters[dIdx],
                    def: context.def(for: defenderSlot, snapshot: snapshot)
                ) {
                    continue
                }
                if isThrow && !canBeThrown(snapshot.fighters[dIdx]) { continue }
                if resolvedMove.guardLevel == .high,
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

                if let followUp = counterFollowUp(
                    defender: snapshot.fighters[dIdx],
                    defenderSlot: defenderSlot,
                    incoming: resolvedMove,
                    snapshot: snapshot
                ) {
                    snapshot.fighters[aIdx].attackContact = true
                    snapshot.fighters[aIdx].strikeSpent = true
                    applyHit(
                        HitResolution(
                            attacker: defenderSlot,
                            defender: attackerSlot,
                            move: followUp,
                            blocked: false
                        ),
                        snapshot: &snapshot
                    )
                    var counterUser = snapshot.fighters[dIdx]
                    counterUser.activeMoveID = followUp.id
                    counterUser.executingMoveID = followUp.id
                    counterUser.kind = .attackRecovery
                    counterUser.stateTick = followUp.startup + followUp.active
                    counterUser.timer = 0
                    counterUser.attackContact = true
                    snapshot.fighters[dIdx] = counterUser
                    continue
                }

                let block = !isThrow && blocks(move: resolvedMove, defender: snapshot.fighters[dIdx])
                if !isThrow, !block, snapshot.fighters[dIdx].armorRemaining > 0 {
                    snapshot.fighters[dIdx].armorRemaining &-= 1
                    snapshot.fighters[aIdx].attackContact = true
                    snapshot.fighters[aIdx].strikeSpent = true // armor absorbs the whole blow, not one frame of it
                    continue
                }
                snapshot.fighters[aIdx].strikeSpent = true
                pending.append(
                    HitResolution(
                        attacker: attackerSlot,
                        defender: defenderSlot,
                        move: resolvedMove,
                        blocked: block
                    )
                )
            }
        }

        resolveProjectiles(snapshot: &snapshot, pending: &pending)

        guard !pending.isEmpty else { return }

        var maxHitstop: Int32 = 0
        for hit in pending {
            // A whiffed hit (a throw box against a defender off the floor) must not freeze the game.
            guard applyHit(hit, snapshot: &snapshot) else {
                // Nothing connected, so the attack is not used up: a later active frame may still land.
                snapshot.fighters[Int(hit.attacker.rawValue)].strikeSpent = false
                continue
            }
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
            // Sim is y-down: only stop fighters sinking below the floor. Pinning y every tick
            // kept jumps on the ground (see JumpThroughResolverTests).
            let floorRaw = StageBounds.floorPx * BoxMath.scale
            if snapshot.fighters[i].position.y.raw > floorRaw {
                snapshot.fighters[i].position.y.raw = floorRaw
            }
        }
    }

    func separatePushboxes(snapshot: inout GameSnapshot) {
        guard snapshot.fighters.count >= 2 else { return }
        let a = worldPushbox(fighter: snapshot.fighters[0], slot: .p1, snapshot: snapshot)
        let b = worldPushbox(fighter: snapshot.fighters[1], slot: .p2, snapshot: snapshot)
        // Bodies only push each other when they actually touch. Without the vertical test a
        // fighter jumping over the opponent shoved them along the ground and could not cross.
        guard a.overlaps(b) else { return }
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

    func dataInvulnerable(_ fighter: FighterState, def: FighterDef?) -> Bool {
        guard let def, FighterStateMachine.isAttackState(fighter.kind) else { return false }
        guard let move = def.moves.first(where: { $0.id == fighter.activeMoveID }) else { return false }
        return move.invulnerableFrames.contains(fighter.stateTick)
    }

    func counterFollowUp(
        defender: FighterState,
        defenderSlot: PlayerSlot,
        incoming: MoveDef,
        snapshot: GameSnapshot
    ) -> MoveDef? {
        guard incoming.guardLevel != .throwAttack else { return nil }
        guard let def = context.def(for: defenderSlot, snapshot: snapshot) else { return nil }
        guard let stance = def.moves.first(where: { $0.id == defender.activeMoveID }) else { return nil }
        guard let counter = stance.counter else { return nil }
        guard defender.stateTick >= counter.startTick, defender.stateTick < counter.endTick else { return nil }
        return def.moves.first(where: { $0.id == counter.followUpMoveID })
    }

    /// Applies one hit. Returns false when it whiffed and changed nothing.
    @discardableResult
    func applyHit(_ hit: HitResolution, snapshot: inout GameSnapshot) -> Bool {
        let aIdx = Int(hit.attacker.rawValue)
        let dIdx = Int(hit.defender.rawValue)
        // Throws are ground grabs (see ThrowLogic.canConnectThrow): a throw box that overlaps
        // a defender who is off the floor whiffs.
        if hit.move.guardLevel == .throwAttack,
           snapshot.fighters[dIdx].position.y.raw < FighterConstants.groundY {
            return false
        }
        snapshot.fighters[aIdx].attackContact = true
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
            return true
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
            return true
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
        return true
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
                if !projectile.hitsAirborne, snapshot.fighters[dIdx].kind == .airborne {
                    continue
                }
                if dataInvulnerable(
                    snapshot.fighters[dIdx],
                    def: context.def(for: defenderSlot, snapshot: snapshot)
                ) {
                    continue
                }
                for hurt in hurtBoxes {
                    let dx = snapshot.fighters[dIdx].position.x.raw
                    let dy = snapshot.fighters[dIdx].position.y.raw
                    let df = snapshot.fighters[dIdx].facingRight
                    let defWorld = BoxMath.worldBox(anchorX: dx, anchorY: dy, box: hurt, facingRight: df)
                    if atkWorld.overlaps(defWorld) {
                        projectile.active = false
                        snapshot.projectiles[pIndex] = projectile
                        let blocked = blocks(
                            move: MoveDef(id: "projectile_\(projectile.id)", name: "Projectile", guardLevel: .mid),
                            defender: snapshot.fighters[dIdx]
                        )
                        if !blocked, snapshot.fighters[dIdx].armorRemaining > 0 {
                            snapshot.fighters[dIdx].armorRemaining &-= 1
                            let ownerIdx = Int(owner.rawValue)
                            if snapshot.fighters.indices.contains(ownerIdx) {
                                snapshot.fighters[ownerIdx].attackContact = true
                            }
                            break
                        }
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