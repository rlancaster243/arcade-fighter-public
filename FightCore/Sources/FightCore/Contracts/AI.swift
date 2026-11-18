public enum Difficulty: UInt8, Sendable, Equatable, Hashable, Codable, CaseIterable {
    case easy = 0
    case normal = 1
    case hard = 2
}

/// Lane L5 provides implementations; core only defines the contract.
public protocol AIController: Sendable {
    func inputs(for slot: PlayerSlot, snapshot: GameSnapshot, rng: inout SeededRNG) -> InputFrame
}