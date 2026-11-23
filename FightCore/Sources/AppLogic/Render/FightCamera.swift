import FightCore

/// Camera scroll in scene pixels (origin bottom-left, arena is `SceneConstants.width` wide).
public struct FightCamera: Sendable, Equatable, Hashable {
    public var scrollX: Int32
    /// Vertical scroll (scene px, >= 0): the arena moves down so a high jump stays on screen.
    public var scrollY: Int32

    public init(scrollX: Int32 = 0, scrollY: Int32 = 0) {
        self.scrollX = scrollX
        self.scrollY = scrollY
    }

    /// Sprite height above the feet that must stay visible (cell content incl. hair).
    public static let fighterHeadroom: Int32 = 100

    /// Scrollable stage is wider than the 384px viewport (fighters use center-origin coords).
    public static let arenaWidth: Int32 = SceneConstants.width * 2
    public static let visibleWidth: Int32 = SceneConstants.width
    /// Scroll that frames the middle of the arena-wide stage art. Fighters live in a one-screen
    /// playfield and `scrollX` stays 0 there, so stage layers are drawn at this base scroll;
    /// without it the view sits on the left half of the painting.
    public static let stageCentreScrollX: Int32 = (arenaWidth - visibleWidth) / 2
}

public enum FightCameraMath: Sendable {
    /// Centers on fighters; clamps so the 384px-wide view stays inside the arena.
    public static func compute(snapshot: GameSnapshot) -> FightCamera {
        let fighters = snapshot.fighters
        guard fighters.count >= 2 else {
            return FightCamera(scrollX: 0)
        }
        let p1x = fighters[0].position.x.raw / Fixed.scale
        let p2x = fighters[1].position.x.raw / Fixed.scale
        let mid = (p1x + p2x) / 2
        let halfVisible = FightCamera.visibleWidth / 2
        let maxScroll = max(FightCamera.arenaWidth - FightCamera.visibleWidth, 0)
        var scroll = mid - halfVisible
        if scroll < 0 { scroll = 0 }
        if scroll > maxScroll { scroll = maxScroll }
        let topY = fighters.map {
            WorldToScene.point(simX: $0.position.x.raw, simY: $0.position.y.raw).y + FightCamera.fighterHeadroom
        }.max() ?? 0
        let scrollY = max(0, topY - SceneConstants.height)
        return FightCamera(scrollX: scroll, scrollY: scrollY)
    }
}