/// Physical key assignments for one keyboard player (virtual key codes).
public struct PlayerKeyBindings: Sendable, Equatable, Hashable, Codable {
    public var up: UInt16
    public var down: UInt16
    public var left: UInt16
    public var right: UInt16
    public var lightPunch: UInt16
    public var heavyPunch: UInt16
    public var lightKick: UInt16
    public var heavyKick: UInt16

    public init(
        up: UInt16,
        down: UInt16,
        left: UInt16,
        right: UInt16,
        lightPunch: UInt16,
        heavyPunch: UInt16,
        lightKick: UInt16,
        heavyKick: UInt16
    ) {
        self.up = up
        self.down = down
        self.left = left
        self.right = right
        self.lightPunch = lightPunch
        self.heavyPunch = heavyPunch
        self.lightKick = lightKick
        self.heavyKick = heavyKick
    }

    public func containsKey(_ keyCode: UInt16) -> Bool {
        keyCode == up || keyCode == down || keyCode == left || keyCode == right
            || keyCode == lightPunch || keyCode == heavyPunch
            || keyCode == lightKick || keyCode == heavyKick
    }
}