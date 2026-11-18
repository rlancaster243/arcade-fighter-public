enum ThrowLogic {
    static func horizontalDistance(_ a: FighterState, _ b: FighterState) -> Int32 {
        let dx = a.position.x.raw - b.position.x.raw
        return dx < 0 ? -dx : dx
    }

    static func canConnectThrow(attacker: FighterState, defender: FighterState, move: MoveDef) -> Bool {
        guard move.inputKind == .throwMove else { return false }
        guard horizontalDistance(attacker, defender) <= FighterConstants.throwRangeRaw else { return false }
        guard !FighterStateMachine.isHitstunLike(defender.kind) else { return false }
        guard defender.kind != .beingThrown else { return false }
        return true
    }

    static func beginThrowStates(
        attacker: inout FighterState,
        defender: inout FighterState,
        move: MoveDef
    ) {
        attacker.kind = .throwing
        attacker.timer = move.recovery + 2
        attacker.activeMoveID = move.id

        defender.kind = .beingThrown
        defender.timer = move.hitstun
        defender.activeMoveID = move.id
        defender.velocity = Vec2(x: .zero, y: .zero)
    }

    static func techThrow(defender: inout FighterState, attacker: inout FighterState) {
        defender.kind = .idle
        defender.timer = 0
        defender.activeMoveID = ""
        attacker.kind = .attackRecovery
        attacker.timer = 0
    }
}