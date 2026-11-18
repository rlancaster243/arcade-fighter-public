import FightCore

/// Per-tick keyboard sampler for one player (no Foundation; safe on the sim hot path).
public struct KeyboardInputSampler: Sendable, Equatable {
    public private(set) var heldKeyCodes: Set<UInt16> = []
    public var bindings: PlayerKeyBindings

    public init(bindings: PlayerKeyBindings) {
        self.bindings = bindings
    }

    public mutating func keyDown(_ keyCode: UInt16) {
        heldKeyCodes.insert(keyCode)
    }

    public mutating func keyUp(_ keyCode: UInt16) {
        heldKeyCodes.remove(keyCode)
    }

    public mutating func clearHeldKeys() {
        heldKeyCodes.removeAll(keepingCapacity: true)
    }

    public func sampleFrame() -> InputFrame {
        let up = heldKeyCodes.contains(bindings.up)
        let down = heldKeyCodes.contains(bindings.down)
        let left = heldKeyCodes.contains(bindings.left)
        let right = heldKeyCodes.contains(bindings.right)
        let direction = DirectionComposer.compose(up: up, down: down, left: left, right: right)

        var frame = InputFrame(direction: direction)
        if heldKeyCodes.contains(bindings.lightPunch) { frame.set(.lightPunch, pressed: true) }
        if heldKeyCodes.contains(bindings.heavyPunch) { frame.set(.heavyPunch, pressed: true) }
        if heldKeyCodes.contains(bindings.lightKick) { frame.set(.lightKick, pressed: true) }
        if heldKeyCodes.contains(bindings.heavyKick) { frame.set(.heavyKick, pressed: true) }
        return frame
    }
}