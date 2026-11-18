public struct IntRect: Sendable, Equatable, Hashable {
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