import FightCore

public enum SparkKind: UInt8, Sendable, Equatable, Hashable {
    case hit = 0
    case block
}

public struct SparkRequest: Sendable, Equatable, Hashable {
    public var kind: SparkKind
    public var worldX: Int32
    public var worldY: Int32

    public init(kind: SparkKind, worldX: Int32, worldY: Int32) {
        self.kind = kind
        self.worldX = worldX
        self.worldY = worldY
    }
}

public enum CombatPresentation: Sendable {
    /// Heavy hits (per design: heavy hitstop 9) use damage at or above this threshold for shake.
    public static let heavyDamageThreshold: Int32 = 70

    public static func sparks(from snapshot: GameSnapshot) -> [SparkRequest] {
        var out: [SparkRequest] = []
        let fighters = snapshot.fighters
        for event in snapshot.events {
            let defenderIndex = event.defender == .p1 ? 0 : 1
            guard fighters.indices.contains(defenderIndex) else { continue }
            let f = fighters[defenderIndex]
            let feet = WorldToScene.point(simX: f.position.x.raw, simY: f.position.y.raw)
            let x = feet.x
            let y = feet.y + 56
            switch event.kind {
            case .hit:
                out.append(SparkRequest(kind: .hit, worldX: x, worldY: y))
            case .block:
                out.append(SparkRequest(kind: .block, worldX: x, worldY: y))
            case .none, .chip, .throwHit, .knockdown, .roundStart, .roundEnd, .matchWin, .timeOver, .whiff:
                break
            }
        }
        return out
    }

    public static func shakeAmplitude(for snapshot: GameSnapshot) -> Int32 {
        for event in snapshot.events {
            if event.kind == .hit, event.damage >= heavyDamageThreshold {
                return 4
            }
        }
        return 0
    }
}