enum RoundRules {
    static func spawnFighter(slot: PlayerSlot) -> FighterState {
        let xPixels: Int32 = slot == .p1 ? -80 : 80
        return FighterState(
            kind: .idle,
            timer: 0,
            position: Vec2(x: Fixed(pixels: xPixels), y: .zero),
            velocity: .zero,
            facingRight: slot == .p1,
            health: 1000,
            meter: 0,
            activeMoveID: "",
            stateTick: 0
        )
    }

    /// Returns the round winner if the round should end this tick.
    static func roundWinnerIfOver(snapshot: GameSnapshot) -> RoundOutcome? {
        guard snapshot.fighters.count >= 2 else { return nil }
        let p1Health = snapshot.fighters[0].health
        let p2Health = snapshot.fighters[1].health

        if p1Health <= 0 || p2Health <= 0 {
            if p1Health <= 0, p2Health <= 0 {
                return RoundOutcome(winner: nil, reason: .roundEnd)
            }
            if p1Health <= 0 {
                return RoundOutcome(winner: .p2, reason: .roundEnd)
            }
            return RoundOutcome(winner: .p1, reason: .roundEnd)
        }

        if snapshot.rules.roundTick >= MatchRules.roundTickLimit {
            if p1Health > p2Health {
                return RoundOutcome(winner: .p1, reason: .timeOver)
            }
            if p2Health > p1Health {
                return RoundOutcome(winner: .p2, reason: .timeOver)
            }
            return RoundOutcome(winner: nil, reason: .timeOver)
        }

        return nil
    }

    static func markKOStates(snapshot: inout GameSnapshot) {
        guard snapshot.fighters.count >= 2 else { return }
        if snapshot.fighters[0].health <= 0 {
            snapshot.fighters[0].kind = .ko
        }
        if snapshot.fighters[1].health <= 0 {
            snapshot.fighters[1].kind = .ko
        }
    }

    static func applyRoundWinStates(snapshot: inout GameSnapshot, winner: PlayerSlot?) {
        guard snapshot.fighters.count >= 2 else { return }
        guard let winner else { return }
        switch winner {
        case .p1:
            snapshot.fighters[0].kind = .win
            snapshot.fighters[1].kind = .ko
        case .p2:
            snapshot.fighters[1].kind = .win
            snapshot.fighters[0].kind = .ko
        }
    }

    static func beginNextRound(snapshot: inout GameSnapshot) {
        snapshot.rules.roundOver = false
        snapshot.rules.roundTick = 0
        snapshot.rules.hitstopRemaining = 0
        snapshot.rules.roundNumber &+= 1
        snapshot.fighters[0] = spawnFighter(slot: .p1)
        snapshot.fighters[1] = spawnFighter(slot: .p2)
        snapshot.projectiles.removeAll(keepingCapacity: true)
        snapshot.events.append(
            GameEvent(kind: .roundStart, tick: snapshot.tick, attacker: .p1, defender: .p2)
        )
    }
}

struct RoundOutcome: Equatable {
    var winner: PlayerSlot?
    var reason: GameEventKind
}