public struct MotionParsingStub: MotionParsing {
    public init() {}

    public mutating func apply(inputs: [InputFrame], to snapshot: inout GameSnapshot) {
        _ = inputs
        _ = snapshot
    }
}