public enum AttackPhase: Equatable, Sendable {
    case startup
    case active
    case recovery
}

public enum MovePhaseMath {
    public static func attackPhase(for stateTick: Int32, move: MoveDef) -> AttackPhase? {
        guard stateTick >= 0 else { return nil }
        if stateTick < move.startup {
            return .startup
        }
        let activeEnd = move.startup + move.active
        if stateTick < activeEnd {
            return .active
        }
        let recoveryEnd = activeEnd + move.recovery
        if stateTick < recoveryEnd {
            return .recovery
        }
        return nil
    }

    public static func attackKind(for phase: AttackPhase) -> FighterStateKind {
        switch phase {
        case .startup: return .attackStartup
        case .active: return .attackActive
        case .recovery: return .attackRecovery
        }
    }

    public static func totalFrames(_ move: MoveDef) -> Int32 {
        move.startup + move.active + move.recovery
    }

    public static func frameBoxes(_ move: MoveDef, stateTick: Int32) -> MoveFrameBoxes {
        guard let phase = attackPhase(for: stateTick, move: move) else {
            return MoveFrameBoxes()
        }
        let index: Int32
        switch phase {
        case .startup:
            return MoveFrameBoxes(hurt: move.frames.hurt)
        case .active:
            index = stateTick - move.startup
        case .recovery:
            index = stateTick - move.startup - move.active
        }

        func pick(_ boxes: [Hitbox], _ idx: Int32) -> [Hitbox] {
            guard !boxes.isEmpty else { return [] }
            let i = min(max(idx, 0), Int32(boxes.count - 1))
            return [boxes[Int(i)]]
        }

        return MoveFrameBoxes(
            hit: pick(move.frames.hit, index),
            hurt: pick(move.frames.hurt, index),
            push: pick(move.frames.push, index),
            throwBoxes: pick(move.frames.throwBoxes, index)
        )
    }

    public static func isInvulnerableFrame(_ boxes: MoveFrameBoxes) -> Bool {
        if boxes.hurt.isEmpty {
            return true
        }
        return boxes.hurt.allSatisfy { $0.w <= 0 || $0.h <= 0 }
    }

    public static func armorHits(for move: MoveDef) -> Int32 {
        move.armorHits
    }
}