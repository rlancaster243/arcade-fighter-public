public struct MatchRules: Sendable, Equatable, Hashable, Codable {
    /// Ticks per round at 60 Hz (99 s).
    public static let roundTickLimit: Int32 = 5940
    public static let roundsToWin: Int32 = 2
    public static let maxRounds: Int32 = 5
    public static let superMeterCost: Int32 = 1000
    public static let meterCap: Int32 = 1000

    public var roundNumber: Int32
    public var p1RoundsWon: Int32
    public var p2RoundsWon: Int32
    public var roundTick: Int32
    public var hitstopRemaining: Int32
    public var roundOver: Bool
    public var matchOver: Bool
    public var winner: PlayerSlot?

    public init(
        roundNumber: Int32 = 1,
        p1RoundsWon: Int32 = 0,
        p2RoundsWon: Int32 = 0,
        roundTick: Int32 = 0,
        hitstopRemaining: Int32 = 0,
        roundOver: Bool = false,
        matchOver: Bool = false,
        winner: PlayerSlot? = nil
    ) {
        self.roundNumber = roundNumber
        self.p1RoundsWon = p1RoundsWon
        self.p2RoundsWon = p2RoundsWon
        self.roundTick = roundTick
        self.hitstopRemaining = hitstopRemaining
        self.roundOver = roundOver
        self.matchOver = matchOver
        self.winner = winner
    }

    public var displaySeconds: Int32 {
        let remaining = Self.roundTickLimit - roundTick
        let sec = (remaining + 59) / 60
        return sec < 0 ? 0 : sec
    }
}