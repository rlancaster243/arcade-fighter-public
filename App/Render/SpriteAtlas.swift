import AppLogic
import SpriteKit
#if os(macOS)
import AppKit
#endif

/// Platform adapter: builds SK textures from a sprite sheet and JSON frames.
final class SpriteAtlas {
    let texture: SKTexture
    let frames: [String: SpriteSheetFrame]

    init(sheetPNG: URL, sheetJSON: URL) throws {
        let loaded = try SpriteSheetLoader.loadFrames(fromSheetJSON: sheetJSON)
        frames = SpriteSheetLoader.indexByName(loaded)
        guard let image = NSImage(contentsOf: sheetPNG) else {
            throw NSError(domain: "SpriteAtlas", code: 1)
        }
        texture = SKTexture(image: image)
        texture.filteringMode = .nearest
    }

    func spriteNode(named name: String) -> SKSpriteNode? {
        guard let frame = frames[name] else { return nil }
        let rect = CGRect(
            x: CGFloat(frame.x),
            y: CGFloat(frame.y),
            width: CGFloat(frame.w),
            height: CGFloat(frame.h)
        )
        let sub = SKTexture(rect: rect, in: texture)
        sub.filteringMode = .nearest
        let node = SKSpriteNode(
            texture: sub,
            size: CGSize(width: CGFloat(frame.w), height: CGFloat(frame.h))
        )
        node.anchorPoint = CGPoint(
            x: CGFloat(frame.anchorX) / CGFloat(frame.w),
            y: CGFloat(frame.anchorY) / CGFloat(frame.h)
        )
        return node
    }
}