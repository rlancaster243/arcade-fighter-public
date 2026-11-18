public struct FighterSteppingStub: FighterStepping {
    public init() {}

    public mutating func stepFighters(snapshot: inout GameSnapshot) {
        _ = snapshot
    }
}