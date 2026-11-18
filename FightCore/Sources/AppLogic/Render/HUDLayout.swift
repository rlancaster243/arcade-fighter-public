import FightCore

public struct HUDModel: Sendable, Equatable, Hashable {
    public var p1Health: Int32
    public var p2Health: Int32
    public var p1Meter: Int32
    public var p2Meter: Int32
    public var healthCap: Int32
    public var meterCap: Int32
    public var timerSeconds: Int32
    public var roundNumber: Int32
    public var p1RoundsWon: Int32
    public var p2RoundsWon: Int32

    public init(
        p1Health: Int32,
        p2Health: Int32,
        p1Meter: Int32,
        p2Meter: Int32,
        healthCap: Int32 = 1000,
        meterCap: Int32 = MatchRules.meterCap,
        timerSeconds: Int32,
        roundNumber: Int32,
        p1RoundsWon: Int32,
        p2RoundsWon: Int32
    ) {
        self.p1Health = p1Health
        self.p2Health = p2Health
        self.p1Meter = p1Meter
        self.p2Meter = p2Meter
        self.healthCap = healthCap
        self.meterCap = meterCap
        self.timerSeconds = timerSeconds
        self.roundNumber = roundNumber
        self.p1RoundsWon = p1RoundsWon
        self.p2RoundsWon = p2RoundsWon
    }
}

public enum HUDLayout: Sendable {
    private static let margin: Int32 = 6
    private static let barHeight: Int32 = 8
    private static let meterHeight: Int32 = 4
    private static let barWidth: Int32 = 120
    private static let topRowY: Int32 = SceneConstants.height - margin - barHeight

    public static func model(from snapshot: GameSnapshot) -> HUDModel {
        let fighters = snapshot.fighters
        let p1 = fighters.indices.contains(0) ? fighters[0] : FighterState()
        let p2 = fighters.indices.contains(1) ? fighters[1] : FighterState()
        return HUDModel(
            p1Health: p1.health,
            p2Health: p2.health,
            p1Meter: p1.meter,
            p2Meter: p2.meter,
            timerSeconds: snapshot.rules.displaySeconds,
            roundNumber: snapshot.rules.roundNumber,
            p1RoundsWon: snapshot.rules.p1RoundsWon,
            p2RoundsWon: snapshot.rules.p2RoundsWon
        )
    }

    public static func p1HealthBarFrame() -> IntRect {
        IntRect(x: margin, y: topRowY, w: barWidth, h: barHeight)
    }

    public static func p2HealthBarFrame() -> IntRect {
        IntRect(
            x: SceneConstants.width - margin - barWidth,
            y: topRowY,
            w: barWidth,
            h: barHeight
        )
    }

    public static func p1MeterBarFrame() -> IntRect {
        IntRect(x: margin, y: topRowY - meterHeight - 2, w: barWidth, h: meterHeight)
    }

    public static func p2MeterBarFrame() -> IntRect {
        IntRect(
            x: SceneConstants.width - margin - barWidth,
            y: topRowY - meterHeight - 2,
            w: barWidth,
            h: meterHeight
        )
    }

    public static func timerFrame() -> IntRect {
        let w: Int32 = 48
        return IntRect(
            x: (SceneConstants.width - w) / 2,
            y: topRowY,
            w: w,
            h: barHeight
        )
    }

  public static func filledWidth(current: Int32, cap: Int32, barWidth: Int32) -> Int32 {
        if cap <= 0 { return 0 }
        let clamped = max(0, min(current, cap))
        return (clamped * barWidth) / cap
    }
}