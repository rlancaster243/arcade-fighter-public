public enum Button: UInt8, Sendable, Equatable, Hashable, Codable, CaseIterable {
    case lightPunch = 0
    case heavyPunch = 1
    case lightKick = 2
    case heavyKick = 3
}

public enum Direction: Int8, Sendable, Equatable, Hashable, Codable {
    case neutral = 0
    case left = 4
    case right = 6
    case up = 8
    case down = 2
    case downLeft = 1
    case downRight = 3
    case upLeft = 7
    case upRight = 9
}

/// Per-player input for one simulation tick.
public struct InputFrame: Sendable, Equatable, Hashable, Codable {
  public var direction: Direction
  public var buttons: UInt8

  public init(direction: Direction = .neutral, buttons: UInt8 = 0) {
    self.direction = direction
    self.buttons = buttons
  }

  public func pressed(_ button: Button) -> Bool {
    (buttons & (1 << button.rawValue)) != 0
  }

  public mutating func set(_ button: Button, pressed: Bool) {
    let mask = UInt8(1 << button.rawValue)
    if pressed {
      buttons |= mask
    } else {
      buttons &= ~mask
    }
  }
}

public enum PlayerSlot: UInt8, Sendable, Equatable, Hashable, Codable, CaseIterable {
    case p1 = 0
    case p2 = 1
}