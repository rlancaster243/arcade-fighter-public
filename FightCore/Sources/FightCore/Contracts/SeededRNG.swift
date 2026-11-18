/// SplitMix64 PRNG; state is part of `GameSnapshot` for determinism.
public struct SeededRNG: Sendable, Equatable, Hashable, Codable {
    public var state: UInt64

    public init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    public mutating func nextBounded(_ upper: UInt64) -> UInt64 {
        guard upper > 0 else { return 0 }
        return next() % upper
    }
}