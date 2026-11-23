/// Drives the red "recent damage" trail behind a health bar.
///
/// Tick-driven (the sim's 60 Hz tick), so it is deterministic and testable without SpriteKit:
/// after a hit the trail holds at the pre-hit value for `holdTicks`, then drains linearly to the
/// current health over `drainTicks` (about half a second in total at 60 Hz).
public struct HUDDamageTrail: Sendable, Equatable {
    public static let holdTicks: Int32 = 4
    public static let drainTicks: Int32 = 26

    private var started = false
    private var shown: Int32 = 0
    private var anchorValue: Int32 = 0
    private var anchorTick: Int32 = 0
    private var lastCurrent: Int32 = 0
    private var lastTick: Int32 = 0

    public init() {}

    /// Returns the value the trail should display this tick (always >= `current`).
    public mutating func update(current: Int32, tick: Int32) -> Int32 {
        // First sample, tick rewind (new match/round), or health restored: snap, no trail.
        if !started || tick < lastTick || current >= shown {
            started = true
            shown = current
            anchorValue = current
            anchorTick = tick
            lastCurrent = current
            lastTick = tick
            return current
        }
        if current < lastCurrent {
            // A new hit: restart the hold from wherever the trail is now.
            anchorValue = shown
            anchorTick = tick
        }
        lastCurrent = current
        lastTick = tick

        let elapsed = tick - anchorTick
        if elapsed <= Self.holdTicks {
            shown = max(current, anchorValue)
        } else {
            let t = min(Self.drainTicks, elapsed - Self.holdTicks)
            let span = Int64(anchorValue) - Int64(current)
            let drained = (span * Int64(t)) / Int64(Self.drainTicks)
            shown = max(current, Int32(Int64(anchorValue) - drained))
        }
        return shown
    }
}
