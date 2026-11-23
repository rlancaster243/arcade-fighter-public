/// Clock for render-side effects (hit flash, sparks). It follows the sim tick while the sim runs
/// and keeps counting in wall time once the snapshot stops advancing (match over, pause), so an
/// effect that started on the last sim tick still plays out instead of freezing on screen.
public struct FXClock: Sendable, Equatable {
    public private(set) var now: Int32 = 0
    private var lastSnapshotTick: Int32?
    private var carry: Double = 0
    /// Ticks credited from wall time since the snapshot last advanced; taken back off the next
    /// sim delta so a rendered frame with no sim step is not counted twice.
    private var wallCredit: Int32 = 0
    /// A stall longer than this is a real stop (pause, match over), not frame jitter.
    private static let maxRefund: Int32 = 2

    public init() {}

    /// Call once per rendered frame. `dt` is seconds since the previous frame.
    @discardableResult
    public mutating func advance(snapshotTick: Int32, dt: Double) -> Int32 {
        defer { lastSnapshotTick = snapshotTick }
        guard let last = lastSnapshotTick else { return now }
        if snapshotTick > last {
            let refund = wallCredit <= Self.maxRefund ? wallCredit : 0
            now &+= max(min(snapshotTick - last, 60) - refund, 0)
            carry = 0
            wallCredit = 0
        } else if snapshotTick < last { // new match: sim tick rewound
            now &+= 1
            carry = 0
            wallCredit = 0
        } else {
            carry += min(max(dt, 0), 0.1) * 60
            let whole = Int32(carry)
            now &+= whole
            wallCredit &+= whole
            carry -= Double(whole)
        }
        return now
    }
}
