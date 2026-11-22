import FightCore

/// Sim → scene coordinates. The sim is y-down (ground at 0, airborne y < 0) with x centred on
/// the stage, in fixed-point raw units. The scene is SpriteKit's: y-up, origin bottom-left,
/// in unscaled scene pixels (`SceneConstants`), floor line at `floorY`.
public enum WorldToScene: Sendable {
    public static let floorY: Int32 = 32

    public static func point(simX: Int32, simY: Int32) -> (x: Int32, y: Int32) {
        (x: simX / Fixed.scale + SceneConstants.width / 2, y: floorY - simY / Fixed.scale)
    }
}
