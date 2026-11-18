/// Phase-0 default name; lane L1 behaviour lives in `MotionParser`.
public typealias MotionParsingStub = MotionParser

public struct MotionParser: MotionParsing, Sendable {
    public struct PlayerTracker: Sendable, Equatable {
        public var buffer: InputRingBuffer
        public var lastResolved: ResolvedInput

        public init() {
            buffer = InputRingBuffer()
            lastResolved = ResolvedInput()
        }
    }

    public private(set) var trackers: [PlayerTracker]
    public var commands: MoveCommandTable

    public init(commands: MoveCommandTable = MoveCommandTable()) {
        trackers = [PlayerTracker(), PlayerTracker()]
        self.commands = commands
    }

    public mutating func apply(inputs: [InputFrame], to snapshot: inout GameSnapshot) {
        for slot in PlayerSlot.allCases {
            let index = Int(slot.rawValue)
            guard index < inputs.count, index < snapshot.fighters.count else { continue }
            let raw = inputs[index]
            var tracker = trackers[index]
            let facing = snapshot.fighters[index].facingRight
            let numpad = FacingInput.logicalNumpad(from: raw.direction, facingRight: facing)
            tracker.buffer.push(numpad: numpad, buttons: raw.buttons)
            let resolved = resolve(raw: raw, buffer: tracker.buffer)
            tracker.lastResolved = resolved
            trackers[index] = tracker
            applyResolved(resolved, logicalNumpad: numpad, index: index, snapshot: &snapshot)
        }
    }

    public func resolvedInput(for slot: PlayerSlot) -> ResolvedInput {
        trackers[Int(slot.rawValue)].lastResolved
    }

    public func tracker(for slot: PlayerSlot) -> PlayerTracker {
        trackers[Int(slot.rawValue)]
    }

    public mutating func push(
        slot: PlayerSlot,
        direction: Direction,
        buttons: UInt8 = 0,
        facingRight: Bool
    ) -> ResolvedInput {
        let index = Int(slot.rawValue)
        var tracker = trackers[index]
        let numpad = FacingInput.logicalNumpad(from: direction, facingRight: facingRight)
        tracker.buffer.push(numpad: numpad, buttons: buttons)
        let frame = InputFrame(direction: direction, buttons: buttons)
        tracker.lastResolved = resolve(raw: frame, buffer: tracker.buffer)
        trackers[index] = tracker
        return tracker.lastResolved
    }

    private func resolve(raw: InputFrame, buffer: InputRingBuffer) -> ResolvedInput {
        guard raw.buttons != 0 else {
            return ResolvedInput(buttons: 0, priority: .normal)
        }
        if let motion = MotionMatcher.matchMotion(in: buffer) {
            let priority: InputPriority = motion == .super236236 ? .superMove : .special
            return ResolvedInput(motion: motion, buttons: raw.buttons, priority: priority)
        }
        return ResolvedInput(buttons: raw.buttons, priority: .normal)
    }

    /// Writes the move id the stepper consumes, or a walk/crouch/jump from the stick.
    private func applyResolved(
        _ resolved: ResolvedInput,
        logicalNumpad: UInt8,
        index: Int,
        snapshot: inout GameSnapshot
    ) {
        guard FighterStateMachine.canStartMove(kind: snapshot.fighters[index].kind) else { return }
        let fighterID = index < snapshot.fighterIDs.count ? snapshot.fighterIDs[index] : ""
        if let moveID = commands.moveID(fighterID: fighterID, resolved: resolved) {
            snapshot.fighters[index].activeMoveID = moveID
            return
        }
        if logicalNumpad == 7 || logicalNumpad == 8 || logicalNumpad == 9 {
            snapshot.fighters[index].activeMoveID = FighterConstants.builtinJumpCommand
            return
        }
        snapshot.fighters[index].kind = locomotionKind(logicalNumpad)
    }

    private func locomotionKind(_ numpad: UInt8) -> FighterStateKind {
        switch numpad {
        case 1, 2, 3:
            return .crouch
        case 4:
            return .walkBack
        case 6:
            return .walkForward
        default:
            return .idle
        }
    }
}
