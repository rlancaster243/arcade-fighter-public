import Foundation
import FightCore

public struct SpriteSheetFrame: Sendable, Equatable, Hashable, Codable {
    public var name: String
    public var x: Int32
    public var y: Int32
    public var w: Int32
    public var h: Int32
    public var anchorX: Int32
    public var anchorY: Int32

    public init(name: String, x: Int32, y: Int32, w: Int32, h: Int32, anchorX: Int32, anchorY: Int32) {
        self.name = name
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.anchorX = anchorX
        self.anchorY = anchorY
    }
}

/// A sheet frame converted into SpriteKit's conventions.
///
/// `sheet.json` uses image pixels with a top-left origin and y pointing down
/// (`docs/fighter-schema.md`: anchor `(w/2, h)` is the bottom-centre of the cell).
/// SpriteKit needs the sub-texture rect in the unit coordinate space of the sheet
/// (0...1, bottom-left origin) and an anchor point in unit space with y pointing up.
public struct SpriteKitFrameGeometry: Sendable, Equatable {
    public var textureX: Double
    public var textureY: Double
    public var textureWidth: Double
    public var textureHeight: Double
    public var anchorX: Double
    public var anchorY: Double
}

extension SpriteSheetFrame {
    public func spriteKitGeometry(sheetWidth: Double, sheetHeight: Double) -> SpriteKitFrameGeometry {
        let sw = max(sheetWidth, 1)
        let sh = max(sheetHeight, 1)
        let fw = max(Double(w), 1)
        let fh = max(Double(h), 1)
        return SpriteKitFrameGeometry(
            textureX: Double(x) / sw,
            textureY: (sh - Double(y) - Double(h)) / sh,
            textureWidth: Double(w) / sw,
            textureHeight: Double(h) / sh,
            anchorX: Double(anchorX) / fw,
            anchorY: 1 - Double(anchorY) / fh
        )
    }
}

/// Logical (scene-space) size of a sprite node.
public struct SpriteNodeSize: Sendable, Equatable {
    public var width: Double
    public var height: Double
}

extension SpriteSheetFrame {
    /// Node size in logical scene points: sheet pixels divided by `texelScale`, so a 2x sheet
    /// sizes its nodes the same as the equivalent 1x sheet. Anchors are unit fractions and
    /// need no adjustment.
    public func nodeSize(texelScale: Int32) -> SpriteNodeSize {
        let scale = Double(max(texelScale, 1))
        return SpriteNodeSize(width: Double(w) / scale, height: Double(h) / scale)
    }
}

/// A decoded `sheet.json`: frame rects in sheet pixels plus the texel density of the sheet.
public struct SpriteSheet: Sendable, Equatable {
    public var frames: [SpriteSheetFrame]
    /// Sheet pixels per logical scene pixel (1 for legacy sheets, 2 for the PS2-era art).
    public var texelScale: Int32

    public init(frames: [SpriteSheetFrame], texelScale: Int32 = 1) {
        self.frames = frames
        self.texelScale = max(texelScale, 1)
    }
}

public enum SpriteSheetLoader {
    private struct ScaledSheet: Decodable {
        var texelScale: Int32?
        var frames: [SpriteSheetFrame]
    }

    /// Accepts either a bare frame array (texelScale 1) or `{"texelScale": N, "frames": [...]}`.
    public static func decode(_ data: Data) throws -> SpriteSheet {
        let decoder = JSONDecoder()
        if SheetJSONShape.isBareArray(data) {
            return SpriteSheet(frames: try decoder.decode([SpriteSheetFrame].self, from: data), texelScale: 1)
        }
        let scaled = try decoder.decode(ScaledSheet.self, from: data)
        return SpriteSheet(frames: scaled.frames, texelScale: scaled.texelScale ?? 1)
    }

    public static func loadSheet(fromSheetJSON url: URL) throws -> SpriteSheet {
        try decode(Data(contentsOf: url))
    }

    public static func loadFrames(fromSheetJSON url: URL) throws -> [SpriteSheetFrame] {
        try loadSheet(fromSheetJSON: url).frames
    }

    public static func indexByName(_ frames: [SpriteSheetFrame]) -> [String: SpriteSheetFrame] {
        Dictionary(uniqueKeysWithValues: frames.map { ($0.name, $0) })
    }
}
