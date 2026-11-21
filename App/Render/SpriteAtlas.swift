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
        // SKTexture(rect:in:) takes unit coordinates with a bottom-left origin; sheet.json is
        // top-left pixels. See SpriteSheetFrame.spriteKitGeometry.
        let sheetSize = texture.size()
        let geometry = frame.spriteKitGeometry(
            sheetWidth: Double(sheetSize.width),
            sheetHeight: Double(sheetSize.height)
        )
        let rect = CGRect(
            x: geometry.textureX,
            y: geometry.textureY,
            width: geometry.textureWidth,
            height: geometry.textureHeight
        )
        let sub = SKTexture(rect: rect, in: texture)
        sub.filteringMode = .nearest
        let node = SKSpriteNode(
            texture: sub,
            size: CGSize(width: CGFloat(frame.w), height: CGFloat(frame.h))
        )
        node.anchorPoint = CGPoint(x: geometry.anchorX, y: geometry.anchorY)
        return node
    }
}