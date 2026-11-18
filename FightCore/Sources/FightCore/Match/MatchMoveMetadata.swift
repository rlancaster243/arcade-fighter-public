/// Per-move data for match directing (loaded outside the per-tick path, keyed by `moveID`).
public struct MatchMoveMetadata: Sendable, Equatable, Hashable {
    public var meterGain: Int32
    public var hitstop: Int32
    public var isSuper: Bool

    public init(meterGain: Int32 = 0, hitstop: Int32 = 0, isSuper: Bool = false) {
        self.meterGain = meterGain
        self.hitstop = hitstop
        self.isSuper = isSuper
    }
}