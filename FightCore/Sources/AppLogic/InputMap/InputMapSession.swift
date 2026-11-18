import FightCore

/// Routes keyboard events to P1/P2 samplers and produces per-tick `InputFrame`s.
public struct InputMapSession: Sendable, Equatable {
    public var settings: InputRemapSettings
    public var playerOne: KeyboardInputSampler
    public var playerTwo: KeyboardInputSampler
    public var gamepad: GamepadInputSampler

    public init(settings: InputRemapSettings = InputRemapSettings()) {
        self.settings = settings
        playerOne = KeyboardInputSampler(bindings: settings.playerOneBindings)
        playerTwo = KeyboardInputSampler(bindings: settings.playerTwoBindings)
        gamepad = GamepadInputSampler(faceMap: settings.gamepadFaceMap)
    }

    public mutating func syncBindingsFromSettings() {
        playerOne.bindings = settings.playerOneBindings
        playerTwo.bindings = settings.playerTwoBindings
        gamepad.faceMap = settings.gamepadFaceMap
    }

    public mutating func applySettings(_ newSettings: InputRemapSettings) {
        settings = newSettings
        syncBindingsFromSettings()
    }

  public func owner(for keyCode: UInt16) -> PlayerSlot? {
        if settings.playerOneBindings.containsKey(keyCode) { return .p1 }
        if settings.playerTwoBindings.containsKey(keyCode) { return .p2 }
        return nil
    }

    public func remapSlot(for keyCode: UInt16, player: PlayerSlot) -> KeyRemapSlot? {
        let bindings = player == .p1 ? settings.playerOneBindings : settings.playerTwoBindings
        if keyCode == bindings.up { return .up }
        if keyCode == bindings.down { return .down }
        if keyCode == bindings.left { return .left }
        if keyCode == bindings.right { return .right }
        if keyCode == bindings.lightPunch { return .lightPunch }
        if keyCode == bindings.heavyPunch { return .heavyPunch }
        if keyCode == bindings.lightKick { return .lightKick }
        if keyCode == bindings.heavyKick { return .heavyKick }
        return nil
    }

    public mutating func keyDown(_ keyCode: UInt16) {
        guard let player = owner(for: keyCode) else { return }
        switch player {
        case .p1: playerOne.keyDown(keyCode)
        case .p2: playerTwo.keyDown(keyCode)
        }
    }

    public mutating func keyUp(_ keyCode: UInt16) {
        guard let player = owner(for: keyCode) else { return }
        switch player {
        case .p1: playerOne.keyUp(keyCode)
        case .p2: playerTwo.keyUp(keyCode)
        }
    }

    /// Keyboard frames; P2 is keyboard-only in versus-on-one-keyboard mode.
    public func keyboardFrames() -> [InputFrame] {
        [playerOne.sampleFrame(), playerTwo.sampleFrame()]
    }

    /// Gamepad overrides player one when connected (arcade mode).
    public mutating func applyGamepadFrame() -> InputFrame? {
        let frame = gamepad.sampleFrame()
        if frame.direction != .neutral || frame.buttons != 0 {
            playerOne = KeyboardInputSampler(bindings: settings.playerOneBindings)
            return frame
        }
        return nil
    }

    public func framesForTick(gamepadOverridesP1: Bool) -> [InputFrame] {
        var frames = keyboardFrames()
        if gamepadOverridesP1 {
            let gp = gamepad.sampleFrame()
            if gp.direction != .neutral || gp.buttons != 0 {
                frames[0] = gp
            }
        }
        return frames
    }
}