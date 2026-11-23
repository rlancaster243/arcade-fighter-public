/// Brings fighters down after the match has ended. The session stops stepping the sim once
/// `matchOver` is set, so a fighter KO'd (or winning) in mid-air would otherwise hang there on
/// the final screen. This applies gravity only: no input, no rules, no events.
public enum PostMatchSettle {
    /// Longest settle the session waits for before showing the result anyway.
    public static let maxTicks: Int32 = 120

    public static func anyAloft(_ snapshot: GameSnapshot) -> Bool {
        snapshot.fighters.contains { $0.position.y.raw < FighterConstants.groundY }
    }

    /// One 60 Hz tick of falling. `gravities` is per fighter slot. Returns true while anyone is
    /// still above the floor.
    @discardableResult
    public static func step(snapshot: inout GameSnapshot, gravities: [Int32]) -> Bool {
        for i in snapshot.fighters.indices {
            guard snapshot.fighters[i].position.y.raw < FighterConstants.groundY else { continue }
            let gravity = max(gravities.indices.contains(i) ? gravities[i] : 1, 1)
            let vy = snapshot.fighters[i].velocity.y.raw + gravity
            let y = snapshot.fighters[i].position.y.raw + vy
            if y >= FighterConstants.groundY {
                snapshot.fighters[i].position.y = Fixed(raw: FighterConstants.groundY)
                snapshot.fighters[i].velocity = Vec2(x: .zero, y: .zero)
                if snapshot.fighters[i].kind == .airborne { snapshot.fighters[i].kind = .idle }
            } else {
                snapshot.fighters[i].position.y = Fixed(raw: y)
                snapshot.fighters[i].velocity.y = Fixed(raw: vy)
            }
        }
        return anyAloft(snapshot)
    }
}
