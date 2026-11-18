/// Frame-data executor and fighter state machine (replaces the Phase 0 stub).
public struct FighterStepper: FighterStepping, Sendable {
    public var definitions: [String: FighterDef]
    private var runtime: [FighterRuntimeSlot]

    public init(definitions: [String: FighterDef] = [:]) {
        self.definitions = definitions
        self.runtime = []
    }

    public mutating func stepFighters(snapshot: inout GameSnapshot) {
        guard snapshot.rules.hitstopRemaining <= 0 else { return }
        ensureRuntime(count: snapshot.fighters.count)

        ProjectileLogic.stepProjectiles(&snapshot.projectiles)

        for slot in PlayerSlot.allCases {
            let idx = Int(slot.rawValue)
            guard idx < snapshot.fighters.count else { continue }
            let defID = idx < snapshot.fighterIDs.count ? snapshot.fighterIDs[idx] : ""
            guard let def = definitions[defID] ?? definitions.values.first else { continue }

            var fighter = snapshot.fighters[idx]
            var slotRuntime = runtime[idx]
            stepOneFighter(
                fighter: &fighter,
                runtime: &slotRuntime,
                def: def,
                slot: slot,
                snapshot: &snapshot
            )
            runtime[idx] = slotRuntime
            snapshot.fighters[idx] = fighter
        }

        handleThrowResolution(snapshot: &snapshot, runtime: &runtime)
    }

    public func isInvulnerable(fighter: FighterState, defID: String) -> Bool {
        guard let def = definitions[defID] ?? definitions.values.first else { return false }
        guard FighterStateMachine.isAttackState(fighter.kind) else { return false }
        guard let move = def.moves.first(where: { $0.id == fighter.activeMoveID }) else { return false }
        if move.invulnerableFrames.contains(fighter.stateTick) {
            return true
        }
        let boxes = MovePhaseMath.frameBoxes(move, stateTick: fighter.stateTick)
        return MovePhaseMath.isInvulnerableFrame(boxes)
    }

    public func armorHitsRemaining(slot: PlayerSlot) -> Int32 {
        let idx = Int(slot.rawValue)
        guard idx < runtime.count else { return 0 }
        return runtime[idx].armorHitsRemaining
    }

    public mutating func registerDefinition(_ def: FighterDef) {
        definitions[def.id] = def
    }

    public mutating func consumeArmorHit(slot: PlayerSlot, snapshot: inout GameSnapshot) -> Bool {
        let idx = Int(slot.rawValue)
        guard idx < snapshot.fighters.count else { return false }
        guard snapshot.fighters[idx].armorRemaining > 0 else { return false }
        snapshot.fighters[idx].armorRemaining &-= 1
        if idx < runtime.count {
            runtime[idx].armorHitsRemaining = snapshot.fighters[idx].armorRemaining
        }
        return true
    }

    private mutating func ensureRuntime(count: Int) {
        if runtime.count < count {
            runtime.append(contentsOf: repeatElement(FighterRuntimeSlot(), count: count - runtime.count))
        }
    }

    private func stepOneFighter(
        fighter: inout FighterState,
        runtime: inout FighterRuntimeSlot,
        def: FighterDef,
        slot: PlayerSlot,
        snapshot: inout GameSnapshot
    ) {
        runtime.executingMoveID = fighter.executingMoveID
        runtime.armorHitsRemaining = fighter.armorRemaining
        captureQueuedCommands(fighter: &fighter, runtime: &runtime)

        var startedThisStep = false
        if FighterStateMachine.canStartMove(kind: fighter.kind) {
            startedThisStep = tryStartQueued(fighter: &fighter, runtime: &runtime, def: def)
        }

        if runtime.jumpQueued,
           FighterStateMachine.isGrounded(fighter.kind),
           FighterStateMachine.canStartMove(kind: fighter.kind)
        {
            fighter.kind = .jumpStartup
            fighter.timer = 0
            runtime.jumpQueued = false
        }

        if let move = def.moves.first(where: { $0.id == fighter.activeMoveID }),
           FighterStateMachine.isAttackState(fighter.kind)
        {
            if !tryCancel(fighter: &fighter, runtime: &runtime, def: def, move: move) {
                if !startedThisStep {
                    let wasActive = fighter.kind == .attackActive
                    let connected = fighter.attackContact
                    let moveID = fighter.activeMoveID
                    FighterStateMachine.advanceAttack(fighter: &fighter, runtime: &runtime, move: move)
                    if wasActive, fighter.kind != .attackActive, !connected, move.active > 0 {
                        let defender: PlayerSlot = slot == .p1 ? .p2 : .p1
                        snapshot.events.append(
                            GameEvent(
                                kind: .whiff,
                                tick: snapshot.tick,
                                attacker: slot,
                                defender: defender,
                                moveID: moveID,
                                damage: 0
                            )
                        )
                    }
                }
                if FighterStateMachine.isAttackState(fighter.kind) {
                    maybeSpawnProjectile(fighter: fighter, move: move, slot: slot, snapshot: &snapshot)
                }
            }
        }

        FighterStateMachine.advanceJump(fighter: &fighter, jumpVelocityY: def.jumpVelocityY)
        FighterStateMachine.advanceTimerStates(fighter: &fighter)
        FighterStateMachine.applyWalkVelocity(
            fighter: &fighter,
            walkForward: def.walkForward,
            walkBack: def.walkBack
        )
        if let move = def.moves.first(where: { $0.id == fighter.activeMoveID }),
           FighterStateMachine.isAttackState(fighter.kind),
           !move.velocities.isEmpty
        {
            FighterStateMachine.applyMoveVelocity(fighter: &fighter, move: move)
        }
        FighterStateMachine.integratePosition(fighter: &fighter, gravity: def.gravity)
    }

    private func captureQueuedCommands(
        fighter: inout FighterState,
        runtime: inout FighterRuntimeSlot
    ) {
        if fighter.activeMoveID == FighterConstants.builtinJumpCommand {
            runtime.jumpQueued = true
            if !FighterStateMachine.isAttackState(fighter.kind) {
                fighter.activeMoveID = ""
            }
            return
        }

        guard !fighter.activeMoveID.isEmpty else { return }

        if FighterStateMachine.isAttackState(fighter.kind) {
            let executing = runtime.executingMoveID
            if !executing.isEmpty, fighter.activeMoveID != executing {
                runtime.queuedMoveID = fighter.activeMoveID
            }
            fighter.activeMoveID = executing
            return
        }

        runtime.queuedMoveID = fighter.activeMoveID
        fighter.activeMoveID = ""
    }

    private func tryStartQueued(
        fighter: inout FighterState,
        runtime: inout FighterRuntimeSlot,
        def: FighterDef
    ) -> Bool {
        guard !runtime.queuedMoveID.isEmpty else { return false }
        let moveID = runtime.queuedMoveID
        guard let move = def.moves.first(where: { $0.id == moveID }) else {
            runtime.queuedMoveID = ""
            return false
        }
        if move.inputKind == .superMove, fighter.meter < MatchRules.superMeterCost {
            runtime.queuedMoveID = ""
            return false
        }
        runtime.queuedMoveID = ""
        FighterStateMachine.beginAttack(fighter: &fighter, moveID: moveID, runtime: &runtime, move: move)
        if move.inputKind == .superMove {
            fighter.meter &-= MatchRules.superMeterCost
        }
        return true
    }

    private func tryCancel(
        fighter: inout FighterState,
        runtime: inout FighterRuntimeSlot,
        def: FighterDef,
        move: MoveDef
    ) -> Bool {
        guard fighter.kind == .attackRecovery else { return false }
        guard !runtime.queuedMoveID.isEmpty else { return false }
        let framesIntoRecovery = fighter.stateTick - move.startup - move.active
        guard framesIntoRecovery >= move.recovery - FighterConstants.normalRecoveryCancelFrames else {
            return false
        }
        let nextID = runtime.queuedMoveID
        runtime.queuedMoveID = ""
        guard let nextMove = def.moves.first(where: { $0.id == nextID }) else { return false }
        FighterStateMachine.beginAttack(fighter: &fighter, moveID: nextID, runtime: &runtime, move: nextMove)
        return true
    }

    private func maybeSpawnProjectile(
        fighter: FighterState,
        move: MoveDef,
        slot: PlayerSlot,
        snapshot: inout GameSnapshot
    ) {
        guard let spawn = move.projectile else { return }
        guard ProjectileLogic.moveSpawnsProjectile(move: move, stateTick: fighter.stateTick) else { return }
        let onScreen = ProjectileLogic.activeCount(ownedBy: slot, in: snapshot)
        guard onScreen < spawn.maxOnScreen else { return }
        let id = ProjectileLogic.spawnID(for: snapshot)
        let projectile = ProjectileLogic.makeProjectile(
            id: id,
            owner: slot,
            facingRight: fighter.facingRight,
            spawn: spawn,
            position: fighter.position
        )
        snapshot.projectiles.append(projectile)
    }

    private func handleThrowResolution(snapshot: inout GameSnapshot, runtime: inout [FighterRuntimeSlot]) {
        guard snapshot.fighters.count >= 2 else { return }
        for attackerSlot in PlayerSlot.allCases {
            let aIdx = Int(attackerSlot.rawValue)
            var attacker = snapshot.fighters[aIdx]
            guard attacker.kind == .attackActive else { continue }
            guard let defID = aIdx < snapshot.fighterIDs.count ? snapshot.fighterIDs[aIdx] : nil,
                  let def = definitions[defID] ?? definitions.values.first,
                  let move = def.moves.first(where: { $0.id == attacker.activeMoveID }),
                  move.inputKind == .throwMove
            else { continue }

            let defenderIdx = aIdx == 0 ? 1 : 0
            var defender = snapshot.fighters[defenderIdx]
            let defenderQueued = defenderIdx < runtime.count ? runtime[defenderIdx].queuedMoveID : ""

            if move.whiffsVsAirborne, defender.kind == .airborne {
                continue
            }

            if defender.activeMoveID == move.id || defenderQueued == move.id {
                if defenderIdx < runtime.count {
                    runtime[defenderIdx].queuedMoveID = ""
                }
                ThrowLogic.techThrow(defender: &defender, attacker: &attacker)
                attacker.attackContact = true
                snapshot.fighters[aIdx] = attacker
                snapshot.fighters[defenderIdx] = defender
                continue
            }

            guard ThrowLogic.canConnectThrow(attacker: attacker, defender: defender, move: move) else {
                continue
            }
            ThrowLogic.beginThrowStates(attacker: &attacker, defender: &defender, move: move)
            attacker.attackContact = true
            snapshot.fighters[aIdx] = attacker
            snapshot.fighters[defenderIdx] = defender
            snapshot.events.append(
                GameEvent(
                    kind: .throwHit,
                    tick: snapshot.tick,
                    attacker: attackerSlot,
                    defender: defenderIdx == 0 ? .p1 : .p2,
                    moveID: move.id,
                    damage: move.damage
                )
            )
        }
    }
}

/// Back-compat name used by frozen `Simulation` defaults.
public typealias FighterSteppingStub = FighterStepper