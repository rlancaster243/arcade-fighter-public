/// Integer axis-aligned box relative to fighter anchor; faces right when stored.
public struct Hitbox: Sendable, Equatable, Hashable, Codable {
    public var x: Int32
    public var y: Int32
    public var w: Int32
    public var h: Int32

    public init(x: Int32, y: Int32, w: Int32, h: Int32) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }
}

public enum GuardLevel: UInt8, Sendable, Equatable, Hashable, Codable {
    case high = 0
    case mid = 1
    case low = 2
    case throwAttack = 3
}