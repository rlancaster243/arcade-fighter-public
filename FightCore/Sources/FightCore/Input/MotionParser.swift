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

    public init() {
        trackers = [PlayerTracker(), PlayerTracker()]
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
            tracker.lastResolved = resolve(raw: raw, buffer: tracker.buffer)
            trackers[index] = tracker
        }
        _ = snapshot.tick
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
}