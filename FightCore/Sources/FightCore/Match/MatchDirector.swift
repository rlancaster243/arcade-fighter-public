/// Back-compat name for `Simulation`'s default (frozen `Sim/` still references this alias).
public typealias MatchDirectingStub = MatchDirector

/// Match directing: rounds, timer, KO, meter, hitstop / super freeze.
public struct MatchDirector: MatchDirecting {
    public var moveMetadata: [String: MatchMoveMetadata]

    public init(moveMetadata: [String: MatchMoveMetadata] = [:]) {
        self.moveMetadata = moveMetadata
    }

    public mutating func applyRules(snapshot: inout GameSnapshot) {
        guard snapshot.fighters.count >= 2 else { return }

        let frozenAtStart = snapshot.rules.hitstopRemaining > 0
        if snapshot.rules.hitstopRemaining > 0 {
            snapshot.rules.hitstopRemaining &-= 1
        }

        if !snapshot.rules.matchOver {
            MeterRules.spendSuperOnStartup(snapshot: &snapshot, moveMetadata: moveMetadata)
            MeterRules.applyEvents(snapshot: &snapshot, moveMetadata: moveMetadata)
            HitstopRules.applyEvents(snapshot: &snapshot, moveMetadata: moveMetadata)
            RoundRules.markKOStates(snapshot: &snapshot)
        }

        if !snapshot.rules.matchOver, !frozenAtStart, !snapshot.rules.roundOver {
            snapshot.rules.roundTick &+= 1
            if let outcome = RoundRules.roundWinnerIfOver(snapshot: snapshot) {
                finishRound(snapshot: &snapshot, outcome: outcome)
            }
        }

        snapshot.tick &+= 1
    }

    private mutating func finishRound(snapshot: inout GameSnapshot, outcome: RoundOutcome) {
        guard !snapshot.rules.roundOver else { return }

        snapshot.rules.roundOver = true
        RoundRules.applyRoundWinStates(snapshot: &snapshot, winner: outcome.winner)

        if let winner = outcome.winner {
            switch winner {
            case .p1:
                snapshot.rules.p1RoundsWon &+= 1
            case .p2:
                snapshot.rules.p2RoundsWon &+= 1
            }
        }

        let endKind: GameEventKind = outcome.reason == .timeOver ? .timeOver : .roundEnd
        snapshot.events.append(
            GameEvent(
                kind: endKind,
                tick: snapshot.tick,
                attacker: .p1,
                defender: .p2
            )
        )

        if snapshot.rules.p1RoundsWon >= MatchRules.roundsToWin {
            snapshot.rules.matchOver = true
            snapshot.rules.winner = .p1
            snapshot.events.append(
                GameEvent(kind: .matchWin, tick: snapshot.tick, attacker: .p1, defender: .p2)
            )
            return
        }
        if snapshot.rules.p2RoundsWon >= MatchRules.roundsToWin {
            snapshot.rules.matchOver = true
            snapshot.rules.winner = .p2
            snapshot.events.append(
                GameEvent(kind: .matchWin, tick: snapshot.tick, attacker: .p2, defender: .p1)
            )
            return
        }

        if snapshot.rules.roundNumber >= MatchRules.maxRounds {
            snapshot.rules.matchOver = true
            if snapshot.rules.p1RoundsWon > snapshot.rules.p2RoundsWon {
                snapshot.rules.winner = .p1
                snapshot.events.append(
                    GameEvent(kind: .matchWin, tick: snapshot.tick, attacker: .p1, defender: .p2)
                )
            } else if snapshot.rules.p2RoundsWon > snapshot.rules.p1RoundsWon {
                snapshot.rules.winner = .p2
                snapshot.events.append(
                    GameEvent(kind: .matchWin, tick: snapshot.tick, attacker: .p2, defender: .p1)
                )
            } else {
                snapshot.rules.winner = nil
            }
            return
        }

        RoundRules.beginNextRound(snapshot: &snapshot)
    }
}