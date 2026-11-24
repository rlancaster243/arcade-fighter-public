enum FighterStateMachine {
    static func canStartMove(kind: FighterStateKind) -> Bool {
        switch kind {
        case .idle, .walkForward, .walkBack, .crouch:
            return true
        default:
            return false
        }
    }

    static func canCancelFromRecovery(kind: FighterStateKind) -> Bool {
        kind == .attackRecovery
    }

    static func isGrounded(_ kind: FighterStateKind) -> Bool {
        switch kind {
        case .airborne, .jumpStartup:
            return false
        default:
            return true
        }
    }

    static func isAttackState(_ kind: FighterStateKind) -> Bool {
        switch kind {
        case .attackStartup, .attackActive, .attackRecovery:
            return true
        default:
            return false
        }
    }

    static func isHitstunLike(_ kind: FighterStateKind) -> Bool {
        switch kind {
        case .hitstun, .blockstunStand, .blockstunCrouch, .knockdown, .beingThrown:
            return true
        default:
            return false
        }
    }

    static func applyWalkVelocity(
        fighter: inout FighterState,
        walkForward: Int32,
        walkBack: Int32
    ) {
        switch fighter.kind {
        case .walkForward:
            let raw = fighter.facingRight ? walkForward : -walkForward
            fighter.velocity = Vec2(x: Fixed(raw: raw), y: .zero)
        case .walkBack:
            let raw = fighter.facingRight ? -walkBack : walkBack
            fighter.velocity = Vec2(x: Fixed(raw: raw), y: .zero)
        default:
            if isGrounded(fighter.kind) {
                fighter.velocity = Vec2(x: .zero, y: fighter.velocity.y)
            }
        }
    }

    static func integratePosition(fighter: inout FighterState, gravity: Int32) {
        let vx = fighter.velocity.x.raw
        var vy = fighter.velocity.y.raw

        // Gravity also applies to anyone above the floor in a "grounded" state: a fighter hit,
        // blocked or thrown out of the air must still come down (see AirHitGravityTests).
        // Attacks are exempt: their height comes from the move's own velocity samples.
        let aloft = fighter.position.y.raw < FighterConstants.groundY && !isAttackState(fighter.kind)
        if !isGrounded(fighter.kind) || aloft {
            vy += gravity
            fighter.velocity.y = Fixed(raw: vy)
        }

        fighter.position = Vec2(
            x: Fixed(raw: fighter.position.x.raw + vx),
            y: Fixed(raw: fighter.position.y.raw + vy)
        )

        if fighter.position.y.raw > FighterConstants.groundY {
            fighter.position.y = Fixed(raw: FighterConstants.groundY)
            fighter.velocity.y = .zero
            if fighter.kind == .airborne {
                fighter.kind = .landing
                fighter.timer = 0
                fighter.stateTick = 0
            }
        }
    }

    static func beginAttack(fighter: inout FighterState, moveID: String, runtime: inout FighterRuntimeSlot, move: MoveDef) {
        fighter.kind = .attackStartup
        fighter.activeMoveID = moveID
        fighter.executingMoveID = moveID
        fighter.stateTick = 0
        fighter.timer = 0
        runtime.executingMoveID = moveID
        runtime.armorHitsRemaining = MovePhaseMath.armorHits(for: move)
        runtime.queuedMoveID = ""
        fighter.attackContact = false
        fighter.strikeSpent = false
        fighter.armorRemaining = move.armorHits
    }

    static func applyMoveVelocity(fighter: inout FighterState, move: MoveDef) {
        let index = Int(fighter.stateTick)
        guard index >= 0, index < move.velocities.count else { return }
        let sample = move.velocities[index]
        let sign: Int32 = fighter.facingRight ? 1 : -1
        fighter.velocity = Vec2(
            x: Fixed(raw: sample.x &* sign),
            y: Fixed(raw: sample.y)
        )
    }

    static func advanceAttack(
        fighter: inout FighterState,
        runtime: inout FighterRuntimeSlot,
        move: MoveDef
    ) {
        fighter.stateTick &+= 1
        guard let phase = MovePhaseMath.attackPhase(for: fighter.stateTick, move: move) else {
            fighter.kind = recoveredKind(fighter)
            fighter.activeMoveID = ""
            fighter.executingMoveID = ""
            fighter.stateTick = 0
            fighter.timer = 0
            fighter.attackContact = false
            fighter.strikeSpent = false
            fighter.armorRemaining = 0
            runtime.executingMoveID = ""
            runtime.armorHitsRemaining = 0
            return
        }
        fighter.kind = MovePhaseMath.attackKind(for: phase)
    }

    static func advanceJump(fighter: inout FighterState, jumpVelocityY: Int32) {
        switch fighter.kind {
        case .jumpStartup:
            fighter.timer &+= 1
            if fighter.timer >= FighterConstants.jumpStartupTicks {
                fighter.kind = .airborne
                fighter.velocity.y = Fixed(raw: jumpVelocityY)
                fighter.timer = 0
            }
        case .landing:
            fighter.timer &+= 1
            if fighter.timer >= FighterConstants.landingTicks {
                fighter.kind = .idle
                fighter.timer = 0
                fighter.stateTick = 0
            }
        default:
            break
        }
    }

    /// State after a stun ends: still above the floor means falling, so the fighter lands through
    /// `.landing` and cannot walk, jump or attack in mid-air as if standing.
    static func recoveredKind(_ fighter: FighterState) -> FighterStateKind {
        fighter.position.y.raw < FighterConstants.groundY ? .airborne : .idle
    }

    static func advanceTimerStates(fighter: inout FighterState) {
        switch fighter.kind {
        case .hitstun, .blockstunStand, .blockstunCrouch, .knockdown, .beingThrown, .getup:
            guard fighter.timer > 0 else {
                fighter.kind = recoveredKind(fighter)
                fighter.timer = 0
                fighter.activeMoveID = ""
                return
            }
            fighter.timer &-= 1
            if fighter.timer == 0 {
                if fighter.kind == .knockdown, fighter.position.y.raw < FighterConstants.groundY {
                    fighter.timer = 1 // still falling: stay down until the floor, then get up
                } else if fighter.kind == .knockdown {
                    fighter.kind = .getup
                    fighter.timer = FighterConstants.defaultGetupTicks
                } else {
                    fighter.kind = recoveredKind(fighter)
                    fighter.activeMoveID = ""
                }
            }
        case .throwing:
            fighter.timer &-= 1
            if fighter.timer <= 0 {
                fighter.kind = recoveredKind(fighter)
                fighter.activeMoveID = ""
            }
        default:
            break
        }
    }
}