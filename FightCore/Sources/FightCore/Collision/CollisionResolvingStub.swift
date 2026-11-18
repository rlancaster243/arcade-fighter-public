public struct CollisionResolvingStub: CollisionResolving {
    public init() {}

    public mutating func resolveMovement(snapshot: inout GameSnapshot) {
        _ = snapshot
    }

    public mutating func resolveHits(snapshot: inout GameSnapshot) {
        _ = snapshot
    }
}