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