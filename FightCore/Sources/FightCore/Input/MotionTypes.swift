public enum MotionPattern: UInt8, Sendable, Equatable, CaseIterable {
    case qcf236 = 0
    case qcb214
    case dp623
    case super236236
}

public enum InputPriority: UInt8, Sendable, Equatable, Comparable {
    case normal = 0
    case special
    case superMove

    public static func < (lhs: InputPriority, rhs: InputPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct ResolvedInput: Sendable, Equatable {
    public var motion: MotionPattern?
    public var buttons: UInt8
    public var priority: InputPriority

    public init(motion: MotionPattern? = nil, buttons: UInt8 = 0, priority: InputPriority = .normal) {
        self.motion = motion
        self.buttons = buttons
        self.priority = priority
    }
}