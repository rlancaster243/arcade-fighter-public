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
    /// Sheet pixels per logical scene pixel; nodes are sized at `w / texelScale`.
    let texelScale: Int32

    init(sheetPNG: URL, sheetJSON: URL) throws {
        let loaded = try SpriteSheetLoader.loadSheet(fromSheetJSON: sheetJSON)
        frames = SpriteSheetLoader.indexByName(loaded.frames)
        texelScale = loaded.texelScale
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
        // Bilinear + mipmaps: 2x art drawn at 1x window scale minifies cleanly instead of shimmering.
        texture.filteringMode = .linear
        texture.usesMipmaps = true
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
        sub.filteringMode = .linear
        sub.usesMipmaps = true
        let logical = frame.nodeSize(texelScale: texelScale)
        let node = SKSpriteNode(
            texture: sub,
            size: CGSize(width: CGFloat(logical.width), height: CGFloat(logical.height))
        )
        node.anchorPoint = CGPoint(x: geometry.anchorX, y: geometry.anchorY)
        return node
    }
}