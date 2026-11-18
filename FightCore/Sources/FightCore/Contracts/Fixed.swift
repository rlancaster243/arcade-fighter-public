/// Fixed-point Q8: 256 raw units = 1 logical unit (typically 1 px).
public struct Fixed: Sendable, Equatable, Hashable, Codable {
    public var raw: Int32

    public static let scale: Int32 = 256
    public static let zero = Fixed(raw: 0)
    public static let one = Fixed(raw: 256)

    public init(raw: Int32) {
        self.raw = raw
    }

    public init(pixels: Int32) {
        self.raw = pixels * Self.scale
    }
}

public struct Vec2: Sendable, Equatable, Hashable, Codable {
    public var x: Fixed
    public var y: Fixed

    public static let zero = Vec2(x: .zero, y: .zero)

    public init(x: Fixed, y: Fixed) {
        self.x = x
        self.y = y
    }
}