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
/// Hit/block spark timing in sim ticks (not render frames: a 120 Hz display halved the old
/// 8-render-frame life to ~66 ms, too short to read).
public enum SparkLife: Sendable {
    public static let ticks: Int32 = 14

    /// Opacity and burst radius (scene px) for a spark `age` ticks old, or nil once finished.
    public static func state(ageTicks age: Int32) -> (alpha: Double, radius: Double)? {
        guard age >= 0, age < ticks else { return nil }
        let t = Double(age) / Double(ticks)
        return (alpha: 1.0 - t * t, radius: 5.0 + 11.0 * t)
    }
}

/// Collects presentation events from every snapshot the renderer is handed, so effects don't
/// depend on the render loop sampling the one snapshot that carried them. Snapshots may repeat
/// events (the session publishes a frame's events cumulatively); `tick` de-duplicates them.
public struct FXEventInbox: Sendable {
    private var pending: [GameEvent] = []
    private var lastTick: Int32 = -1
    private var lastSnapshotTick: Int32 = -1

    public init() {}

    public mutating func receive(_ snapshot: GameSnapshot) {
        if snapshot.tick < lastSnapshotTick { lastTick = -1 } // new match / round reset
        lastSnapshotTick = snapshot.tick
        let fresh = snapshot.events.filter { $0.tick > lastTick }
        guard let newest = fresh.map(\.tick).max() else { return }
        pending.append(contentsOf: fresh)
        lastTick = newest
    }

    /// Events received since the last drain, oldest first.
    public mutating func drain() -> [GameEvent] {
        defer { pending.removeAll(keepingCapacity: true) }
        return pending
    }
}
