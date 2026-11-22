import FightCore

public enum SparkKind: UInt8, Sendable, Equatable, Hashable {
    case hit = 0
    case block
}

public struct SparkRequest: Sendable, Equatable, Hashable {
    public var kind: SparkKind
    public var worldX: Int32
    public var worldY: Int32
    /// Hit with damage >= `CombatPresentation.heavyDamageThreshold`: bigger spark plus a struck-fighter flash.
    public var heavy: Bool
    /// Index into `snapshot.fighters` of the fighter that was struck or blocked.
    public var defenderIndex: Int

    public init(kind: SparkKind, worldX: Int32, worldY: Int32, heavy: Bool = false, defenderIndex: Int = 0) {
        self.kind = kind
        self.worldX = worldX
        self.worldY = worldY
        self.heavy = heavy
        self.defenderIndex = defenderIndex
    }

    /// Uniform scale applied to the whole spark node: block smaller, heavy bigger.
    public var scale: Double {
        if kind == .block { return 0.7 }
        return heavy ? 1.6 : 1.0
    }

    /// Short radiating streak lines (6...10).
    public var streakCount: Int {
        if kind == .block { return 6 }
        return heavy ? 10 : 8
    }
}

/// Deterministic streak layout so a spark looks the same on every run (and is testable).
public enum SparkShape: Sendable {
    /// `count` angles in [0, 2π): evenly spaced rays rotated by `seed`, each nudged by a bounded jitter.
    public static func streakAngles(count: Int, seed: Int32) -> [Double] {
        guard count > 0 else { return [] }
        let step = 2.0 * Double.pi / Double(count)
        var h = UInt32(bitPattern: seed) &* 2_654_435_761 &+ 0x9E37_79B9
        func next() -> Double {
            h ^= h << 13
            h ^= h >> 17
            h ^= h << 5
            return Double(h % 1000) / 1000.0
        }
        let start = next() * step
        return (0..<count).map { i in
            let jitter = (next() - 0.5) * step * 0.4
            let a = (start + Double(i) * step + jitter).truncatingRemainder(dividingBy: 2.0 * Double.pi)
            return a < 0 ? a + 2.0 * Double.pi : a
        }
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
                out.append(SparkRequest(
                    kind: .hit, worldX: x, worldY: y,
                    heavy: event.damage >= heavyDamageThreshold, defenderIndex: defenderIndex
                ))
            case .block:
                out.append(SparkRequest(kind: .block, worldX: x, worldY: y, defenderIndex: defenderIndex))
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

/// White flash on the struck fighter's sprite after a heavy hit. ~3 sim ticks (50 ms), single pulse,
/// never full-screen: photosensitivity.
public enum HitFlashLife: Sendable {
    public static let ticks: Int32 = 3

    /// Colour-blend factor toward white for a flash `age` ticks old, or nil once finished.
    public static func blend(ageTicks age: Int32) -> Double? {
        guard age >= 0, age < ticks else { return nil }
        return 1.0 - 0.15 * Double(age)
    }
}

/// Per-fighter flash start ticks. Pure state the renderer owns; no clock of its own.
public struct HitFlashTracker: Sendable, Equatable {
    private var startTick: [Int: Int32] = [:]

    public init() {}

    public mutating func trigger(slot: Int, tick: Int32) {
        startTick[slot] = tick
    }

    /// 0 when `slot` isn't flashing at `tick` (including a rewound tick after a new match).
    public func blend(slot: Int, tick: Int32) -> Double {
        guard let start = startTick[slot] else { return 0 }
        return HitFlashLife.blend(ageTicks: tick - start) ?? 0
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
