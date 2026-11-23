/// Clock for render-side effects (hit flash, sparks). It follows the sim tick while the sim runs
/// and keeps counting in wall time once the snapshot stops advancing (match over, pause), so an
/// effect that started on the last sim tick still plays out instead of freezing on screen.
public struct FXClock: Sendable, Equatable {
    public private(set) var now: Int32 = 0
    private var lastSnapshotTick: Int32?
    private var carry: Double = 0

    public init() {}

    /// Call once per rendered frame. `dt` is seconds since the previous frame.
    @discardableResult
    public mutating func advance(snapshotTick: Int32, dt: Double) -> Int32 {
        defer { lastSnapshotTick = snapshotTick }
        guard let last = lastSnapshotTick else { return now }
        if snapshotTick > last {
            now &+= min(snapshotTick - last, 60)
            carry = 0
        } else if snapshotTick < last { // new match: sim tick rewound
            now &+= 1
            carry = 0
        } else {
            carry += min(max(dt, 0), 0.1) * 60
            let whole = Int32(carry)
            now &+= whole
            carry -= Double(whole)
        }
        return now
    }
}
