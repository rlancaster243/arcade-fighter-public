import FightCore

/// Picks the sprite frame for a fighter. Frame names are the contract with
/// scripts/art/gen_fighters.py. Returns candidates most-specific first, always ending in
/// "idle_0", so a sheet missing a frame degrades to a pose instead of nothing.
public enum SpriteSelection: Sendable {
    /// Animation rates in sim ticks per frame (60 Hz).
    static let idleRate: Int32 = 10
    static let walkRate: Int32 = 6
    static let hitRate: Int32 = 4
    static let winRate: Int32 = 20

    public static func frameName(for fighter: FighterState, tick: Int32 = 0) -> String {
        frameCandidates(for: fighter, tick: tick)[0]
    }

    public static func frameCandidates(for fighter: FighterState, tick: Int32) -> [String] {
        let t = max(tick, 0)
        var c: [String]
        switch fighter.kind {
        case .idle:
            c = ["idle_\((t / idleRate) % 4)"]
        case .walkForward:
            c = ["walk_\((t / walkRate) % 6)"]
        case .walkBack:
            c = ["walk_\(5 - (t / walkRate) % 6)"]
        case .crouch:
            c = ["crouch_0"]
        case .jumpStartup:
            c = ["jump_0"]
        case .airborne:
            let vy = fighter.velocity.y.raw
            let apexBand = 3 * Fixed.scale
            c = [vy < -apexBand ? "jump_1" : (vy > apexBand ? "jump_3" : "jump_2")]
        case .landing:
            c = ["land_0", "crouch_0"]
        case .attackStartup:
            c = moveFrame(fighter, 0)
        case .attackActive:
            c = moveFrame(fighter, 1)
        case .attackRecovery:
            c = moveFrame(fighter, 2)
        case .hitstun:
            c = ["hit_\((max(fighter.stateTick, 0) / hitRate) % 2)", "hit_0"]
        case .blockstunStand:
            c = ["block_0"]
        case .blockstunCrouch:
            c = ["block_1", "block_0"]
        case .knockdown:
            c = [fighter.stateTick < 12 ? "down_0" : "down_1", "down_1"]
        case .getup:
            c = ["getup_0", "crouch_0"]
        case .throwStartup:
            c = moveFrame(fighter, 0) + ["throw_0"]
        case .throwing:
            c = moveFrame(fighter, 1) + ["throw_0"]
        case .beingThrown:
            c = ["thrown_0", "hit_1"]
        case .ko:
            c = ["ko_0", "down_1"]
        case .win:
            c = ["win_\((t / winRate) % 2)", "win_0"]
        }
        c.append("idle_0")
        return c
    }

    private static func moveFrame(_ fighter: FighterState, _ phase: Int) -> [String] {
        fighter.activeMoveID.isEmpty ? [] : ["\(fighter.activeMoveID)_\(phase)"]
    }
}
