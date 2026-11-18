public struct CPUAIController: AIController {
    public let profile: DifficultyProfile

    public init(profile: DifficultyProfile) {
        self.profile = profile
    }

  public init(difficulty: Difficulty, matchSeed: UInt64) {
        self.profile = DifficultyProfile.seeded(difficulty: difficulty, matchSeed: matchSeed)
    }

    public func inputs(for slot: PlayerSlot, snapshot: GameSnapshot, rng: inout SeededRNG) -> InputFrame {
        guard snapshot.fighters.count >= 2 else { return InputFrame() }
        let period = max(4, profile.reactionDelayTicks)
        let epoch = snapshot.tick / period
        let phase = snapshot.tick % period
        var epochRNG = SeededRNG(
            seed: profile.decisionSeed
                ^ (UInt64(bitPattern: Int64(epoch)) &* 0x85EB_CA6B)
                ^ (UInt64(slot.rawValue) << 48)
        )
        let intent = pickIntent(slot: slot, snapshot: snapshot, rng: &epochRNG)
        var frame = frameForIntent(intent, phase: phase, period: period, slot: slot, snapshot: snapshot)
        applyInputAccuracy(&frame, rng: &rng)
        return frame
    }

    private enum Intent: UInt8, Sendable {
        case idle
        case walkIn
        case walkOut
        case crouch
        case jump
        case attackLightPunch
        case attackHeavyPunch
        case attackLightKick
        case attackHeavyKick
        case block
        case special
        case superMove
    }

    private func pickIntent(slot: PlayerSlot, snapshot: GameSnapshot, rng: inout SeededRNG) -> Intent {
        let weights: [(Intent, Int32)] = [
            (.walkIn, 280),
            (.walkOut, 120),
            (.crouch, 80),
            (.jump, 90),
            (.attackLightPunch, 220),
            (.attackHeavyPunch, 140),
            (.attackLightKick, 160),
            (.attackHeavyKick, 120),
            (.block, profile.blockRatePermille),
            (.special, profile.specialRatePermille),
            (.superMove, profile.superRatePermille),
            (.idle, 100),
        ]
        let total = weights.reduce(Int32(0)) { $0 + $1.1 }
        guard total > 0 else { return .idle }
        let roll = Int32(rng.nextBounded(UInt64(total)))
        var acc: Int32 = 0
        for (intent, w) in weights {
            acc += w
            if roll < acc { return intent }
        }
        return .idle
    }

    private func frameForIntent(
        _ intent: Intent,
        phase: Int32,
        period: Int32,
        slot: PlayerSlot,
        snapshot: GameSnapshot
    ) -> InputFrame {
        var frame = InputFrame()
        let toward = towardOpponent(slot: slot, snapshot: snapshot)
        let back = backFromOpponent(slot: slot, snapshot: snapshot)

        switch intent {
        case .idle:
            frame.direction = .neutral
        case .walkIn:
            frame.direction = toward
        case .walkOut:
            frame.direction = back
        case .crouch:
            frame.direction = .down
        case .jump:
            frame.direction = toward.jumpComponent()
        case .attackLightPunch:
            frame.direction = toward
            frame.set(.lightPunch, pressed: true)
        case .attackHeavyPunch:
            frame.direction = toward
            frame.set(.heavyPunch, pressed: true)
        case .attackLightKick:
            frame.direction = toward
            frame.set(.lightKick, pressed: true)
        case .attackHeavyKick:
            frame.direction = toward
            frame.set(.heavyKick, pressed: true)
        case .block:
            frame.direction = back
        case .special:
            frame = motionPhase(phase: phase, period: period, toward: toward, button: .heavyPunch)
        case .superMove:
            frame = superMotionPhase(phase: phase, period: period, toward: toward)
        }
        return frame
    }

    private func motionPhase(phase: Int32, period: Int32, toward: Direction, button: Button) -> InputFrame {
        var frame = InputFrame()
        let steps = min(period, 4)
        switch phase % steps {
        case 0:
            frame.direction = .down
        case 1:
            frame.direction = toward.quarterDownForward()
        case 2:
            frame.direction = toward
            frame.set(button, pressed: true)
        default:
            frame.direction = toward
        }
        return frame
    }

    private func superMotionPhase(phase: Int32, period: Int32, toward: Direction) -> InputFrame {
        var frame = InputFrame()
        let steps = min(period, 6)
        switch phase % steps {
        case 0, 2, 4:
            frame.direction = .down
        case 1, 3, 5:
            frame.direction = toward.quarterDownForward()
        default:
            frame.direction = toward
            frame.set(.heavyPunch, pressed: true)
            frame.set(.heavyKick, pressed: true)
        }
        return frame
    }

    private func applyInputAccuracy(_ frame: inout InputFrame, rng: inout SeededRNG) {
        guard frame.buttons != 0 else { return }
        let miss = 1000 - profile.inputAccuracyPermille
        guard miss > 0 else { return }
        if Int32(rng.nextBounded(1000)) < miss {
            frame.buttons = 0
        } else if Int32(rng.nextBounded(1000)) < miss / 2 {
            let alt = Button(rawValue: UInt8(rng.nextBounded(4))) ?? .lightPunch
            frame.buttons = 0
            frame.set(alt, pressed: true)
        }
    }

    private func towardOpponent(slot: PlayerSlot, snapshot: GameSnapshot) -> Direction {
        let selfIdx = Int(slot.rawValue)
        let oppIdx = 1 - selfIdx
        let selfX = snapshot.fighters[selfIdx].position.x.raw
        let oppX = snapshot.fighters[oppIdx].position.x.raw
        return selfX < oppX ? .right : .left
    }

    private func backFromOpponent(slot: PlayerSlot, snapshot: GameSnapshot) -> Direction {
        let toward = towardOpponent(slot: slot, snapshot: snapshot)
        return toward == .right ? .left : .right
    }
}

private extension Direction {
    func jumpComponent() -> Direction {
        switch self {
        case .right: return .upRight
        case .left: return .upLeft
        default: return .up
        }
    }

    func quarterDownForward() -> Direction {
        switch self {
        case .right: return .downRight
        case .left: return .downLeft
        default: return .down
        }
    }
}