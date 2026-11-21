import Foundation

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

public enum SpriteSheetLoader {
    public static func loadFrames(fromSheetJSON url: URL) throws -> [SpriteSheetFrame] {
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode([SpriteSheetFrame].self, from: data)
        return decoded
    }

    public static func indexByName(_ frames: [SpriteSheetFrame]) -> [String: SpriteSheetFrame] {
        Dictionary(uniqueKeysWithValues: frames.map { ($0.name, $0) })
    }
}