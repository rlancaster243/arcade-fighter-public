import FightCore

/// Camera scroll in scene pixels (origin bottom-left, arena is `SceneConstants.width` wide).
public struct FightCamera: Sendable, Equatable, Hashable {
    public var scrollX: Int32

    public init(scrollX: Int32 = 0) {
        self.scrollX = scrollX
    }

    public static let arenaWidth: Int32 = SceneConstants.width
    public static let visibleWidth: Int32 = SceneConstants.width
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
        return FightCamera(scrollX: scroll)
    }
}