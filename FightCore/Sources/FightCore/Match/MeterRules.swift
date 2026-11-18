/// Super-meter bookkeeping (0…`MatchRules.meterCap`).
enum MeterRules {
    static func clamp(_ value: inout Int32) {
        if value < 0 {
            value = 0
        } else if value > MatchRules.meterCap {
            value = MatchRules.meterCap
        }
    }

    static func add(_ amount: Int32, to meter: inout Int32) {
        guard amount > 0 else { return }
        meter &+= amount
        clamp(&meter)
    }

    static func spend(_ amount: Int32, from meter: inout Int32) -> Bool {
        guard amount > 0, meter >= amount else { return false }
        meter &-= amount
        return true
    }

    /// Apply meter changes from combat events using move metadata.
    static func applyEvents(
        snapshot: inout GameSnapshot,
        moveMetadata: [String: MatchMoveMetadata]
    ) {
        guard snapshot.fighters.count >= 2 else { return }

        for event in snapshot.events {
            let meta = moveMetadata[event.moveID] ?? MatchMoveMetadata()
            let attackerIdx = Int(event.attacker.rawValue)
            let defenderIdx = Int(event.defender.rawValue)
            guard attackerIdx < snapshot.fighters.count, defenderIdx < snapshot.fighters.count else {
                continue
            }

            switch event.kind {
            case .hit:
                add(meta.meterGain, to: &snapshot.fighters[attackerIdx].meter)
                let defenderGain = event.damage * 25 / 100
                add(defenderGain, to: &snapshot.fighters[defenderIdx].meter)
            case .block:
                let gain = meta.meterGain / 2
                add(gain, to: &snapshot.fighters[attackerIdx].meter)
            case .chip:
                let gain = meta.meterGain / 2
                add(gain, to: &snapshot.fighters[attackerIdx].meter)
                let defenderGain = event.damage * 25 / 100
                add(defenderGain, to: &snapshot.fighters[defenderIdx].meter)
            case .throwHit:
                add(meta.meterGain, to: &snapshot.fighters[attackerIdx].meter)
                let defenderGain = event.damage * 25 / 100
                add(defenderGain, to: &snapshot.fighters[defenderIdx].meter)
            default:
                break
            }
        }

        for i in snapshot.fighters.indices {
            clamp(&snapshot.fighters[i].meter)
        }
    }

    /// Deduct super cost on the first tick of a super's startup.
    static func spendSuperOnStartup(
        snapshot: inout GameSnapshot,
        moveMetadata: [String: MatchMoveMetadata]
    ) {
        for i in snapshot.fighters.indices {
            let fighter = snapshot.fighters[i]
            guard fighter.kind == .attackStartup, fighter.stateTick == 0 else { continue }
            guard let meta = moveMetadata[fighter.activeMoveID], meta.isSuper else { continue }
            _ = spend(MatchRules.superMeterCost, from: &snapshot.fighters[i].meter)
        }
    }
}