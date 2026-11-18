import FightCore

public enum SpriteSelection: Sendable {
    public static func frameName(for fighter: FighterState) -> String {
        switch fighter.kind {
        case .idle, .win, .ko:
            return "idle_0"
        case .walkForward, .walkBack:
            return "idle_0"
        case .crouch:
            return "idle_0"
        case .jumpStartup, .airborne, .landing:
            return "idle_0"
        case .attackStartup, .attackActive, .attackRecovery:
            return fighter.activeMoveID.isEmpty ? "idle_0" : fighter.activeMoveID
        case .hitstun, .blockstunStand, .blockstunCrouch:
            return "idle_0"
        case .knockdown, .getup:
            return "idle_0"
        case .throwStartup, .throwing, .beingThrown:
            return "idle_0"
        }
    }
}