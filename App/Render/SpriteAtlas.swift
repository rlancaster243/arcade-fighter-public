import AppLogic
import ImageIO
import SpriteKit

/// Platform adapter: builds SK textures from a sprite sheet and JSON frames.
final class SpriteAtlas {
    let texture: SKTexture
    let frames: [String: SpriteSheetFrame]
    /// Sheet size in pixels, the space `sheet.json` rects are written in.
    private let sheetPixelWidth: Double
    private let sheetPixelHeight: Double

    init(sheetPNG: URL, sheetJSON: URL) throws {
        let loaded = try SpriteSheetLoader.loadFrames(fromSheetJSON: sheetJSON)
        frames = SpriteSheetLoader.indexByName(loaded)
        // Decode to a CGImage rather than NSImage: NSImage sizes in points from the PNG's DPI
        // metadata, so a 144-dpi sheet would report half its pixel size and every frame rect
        // would land in the wrong place.
        guard let source = CGImageSourceCreateWithURL(sheetPNG as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw NSError(
                domain: "SpriteAtlas",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "could not decode \(sheetPNG.lastPathComponent)"]
            )
        }
        sheetPixelWidth = Double(image.width)
        sheetPixelHeight = Double(image.height)
        texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
    }

    func spriteNode(named name: String) -> SKSpriteNode? {
        guard let frame = frames[name] else { return nil }
        // SKTexture(rect:in:) takes unit coordinates with a bottom-left origin; sheet.json is
        // top-left pixels. See SpriteSheetFrame.spriteKitGeometry.
        let geometry = frame.spriteKitGeometry(
            sheetWidth: sheetPixelWidth,
            sheetHeight: sheetPixelHeight
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