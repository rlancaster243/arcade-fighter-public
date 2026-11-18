/// Hexagonal seams between simulation steps (implementations live in lane directories).
public protocol MotionParsing: Sendable {
    mutating func apply(inputs: [InputFrame], to snapshot: inout GameSnapshot)
}

public protocol FighterStepping: Sendable {
    mutating func stepFighters(snapshot: inout GameSnapshot)
}

public protocol CollisionResolving: Sendable {
    mutating func resolveMovement(snapshot: inout GameSnapshot)
    mutating func resolveHits(snapshot: inout GameSnapshot)
}

public protocol MatchDirecting: Sendable {
    mutating func applyRules(snapshot: inout GameSnapshot)
}