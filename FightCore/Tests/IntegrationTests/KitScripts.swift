import FightCore

struct KitScript {
    var frames: [[InputFrame]]
    var meterP1: Int32
    var meterP2: Int32
    var p1XPx: Int32?
    var p2XPx: Int32?
}

struct KitTrace {
    var moveIDs: Set<String> = []
    var events: [(GameEventKind, String)] = []
    var spawned: [(id: UInt32, speedRaw: Int32, hitsAirborne: Bool)] = []
    var rocketArmor: [Int32] = []
}

enum KitMotion {
    static func screen(_ logical: Direction, facingRight: Bool) -> Direction {
        guard !facingRight else { return logical }
        switch logical {
        case .neutral:
            return .neutral
        case .left:
            return .right
        case .right:
            return .left
        case .up:
            return .up
        case .down:
            return .down
        case .downLeft:
            return .downRight
        case .downRight:
            return .downLeft
        case .upLeft:
            return .upRight
        case .upRight:
            return .upLeft
        }
    }

    static func sequence(_ dirs: [Direction], button: Button, facingRight: Bool) -> [InputFrame] {
        dirs.enumerated().map { index, dir in
            var frame = InputFrame(direction: screen(dir, facingRight: facingRight))
            if index == dirs.count - 1 {
                frame.set(button, pressed: true)
            }
            return frame
        }
    }

    static func qcf(_ button: Button, facingRight: Bool) -> [InputFrame] {
        sequence([.down, .downRight, .right], button: button, facingRight: facingRight)
    }

    static func qcb(_ button: Button, facingRight: Bool) -> [InputFrame] {
        sequence([.down, .downLeft, .left], button: button, facingRight: facingRight)
    }

    static func dp(_ button: Button, facingRight: Bool) -> [InputFrame] {
        sequence([.right, .down, .downRight], button: button, facingRight: facingRight)
    }

    static func super236(_ button: Button, facingRight: Bool) -> [InputFrame] {
        sequence(
            [.down, .downRight, .right, .down, .downRight, .right],
            button: button,
            facingRight: facingRight
        )
    }

    static func toss() -> InputFrame {
        var frame = InputFrame()
        frame.set(.lightPunch, pressed: true)
        frame.set(.lightKick, pressed: true)
        return frame
    }

    static func walkForward(facingRight: Bool) -> InputFrame {
        InputFrame(direction: screen(.right, facingRight: facingRight))
    }
}

private struct PairBuilder {
    private var p1: [InputFrame] = []
    private var p2: [InputFrame] = []

    mutating func hold(p1: InputFrame = InputFrame(), p2: InputFrame = InputFrame(), ticks: Int) {
        for _ in 0 ..< ticks {
            self.p1.append(p1)
            self.p2.append(p2)
        }
    }

    mutating func p1Only(_ frames: [InputFrame]) {
        for frame in frames {
            p1.append(frame)
            p2.append(InputFrame())
        }
    }

    mutating func p1Motion(_ frames: [InputFrame], p2Button: Button?) {
        for (index, frame) in frames.enumerated() {
            p1.append(frame)
            if let p2Button, index == frames.count - 1 {
                var other = InputFrame()
                other.set(p2Button, pressed: true)
                p2.append(other)
            } else {
                p2.append(InputFrame())
            }
        }
    }

    var frames: [[InputFrame]] {
        precondition(p1.count == p2.count)
        return zip(p1, p2).map { [$0.0, $0.1] }
    }
}

enum KitScripts {
    static func script(for scenarioID: String) -> KitScript? {
        switch scenarioID {
        case "script-kestrel-kit":
            return kestrel()
        case "script-bruno-kit":
            return bruno()
        case "script-ilse-kit":
            return ilse()
        case "script-rook-kit":
            return rook()
        default:
            return nil
        }
    }

    /// 8+1+100+6+100+3+100+3+100+3+100+3+100 = 627
    /// Super comes before Crag Hook. Every active frame of Crag Hook deals full damage, which KOs Bruno and spends the meter before a later super can start.
    static func kestrel() -> KitScript {
        var build = PairBuilder()
        build.hold(p1: KitMotion.walkForward(facingRight: true), ticks: 8)
        build.hold(p1: KitMotion.toss(), ticks: 1)
        build.hold(ticks: 100)
        build.p1Only(KitMotion.super236(.lightPunch, facingRight: true))
        build.hold(ticks: 100)
        build.p1Only(KitMotion.qcf(.lightKick, facingRight: true))
        build.hold(ticks: 100)
        build.p1Only(KitMotion.qcf(.heavyKick, facingRight: true))
        build.hold(ticks: 100)
        build.p1Only(KitMotion.dp(.lightPunch, facingRight: true))
        build.hold(ticks: 100)
        build.p1Only(KitMotion.dp(.heavyPunch, facingRight: true))
        build.hold(ticks: 100)
        return KitScript(frames: build.frames, meterP1: 1000, meterP2: 0, p1XPx: -30, p2XPx: 30)
    }

    /// 3+70+10+1+60+6+70+3+60 = 283
    static func bruno() -> KitScript {
        var build = PairBuilder()
        build.p1Only(KitMotion.qcf(.lightKick, facingRight: true))
        build.hold(ticks: 70)
        build.hold(p1: KitMotion.walkForward(facingRight: true), ticks: 10)
        build.hold(p1: KitMotion.toss(), ticks: 1)
        build.hold(ticks: 60)
        build.p1Only(KitMotion.super236(.heavyPunch, facingRight: true))
        build.hold(ticks: 70)
        build.p1Only(KitMotion.qcb(.lightPunch, facingRight: true))
        build.hold(ticks: 60)
        return KitScript(frames: build.frames, meterP1: 1000, meterP2: 0, p1XPx: -20, p2XPx: 20)
    }

    /// 8+1+60+3+100+3+100+3+100+3+100+6+100 = 587
    /// The second 236 is more than 20 ticks after the first, so it stays Prayer Bead and not Rosary Storm.
    static func ilse() -> KitScript {
        var build = PairBuilder()
        build.hold(p1: KitMotion.walkForward(facingRight: true), ticks: 8)
        build.hold(p1: KitMotion.toss(), ticks: 1)
        build.hold(ticks: 60)
        build.p1Only(KitMotion.qcf(.lightPunch, facingRight: true))
        build.hold(ticks: 100)
        build.p1Only(KitMotion.qcf(.heavyPunch, facingRight: true))
        build.hold(ticks: 100)
        build.p1Only(KitMotion.qcb(.lightKick, facingRight: true))
        build.hold(ticks: 100)
        build.p1Only(KitMotion.qcb(.heavyKick, facingRight: true))
        build.hold(ticks: 100)
        build.p1Only(KitMotion.super236(.lightPunch, facingRight: true))
        build.hold(ticks: 100)
        return KitScript(frames: build.frames, meterP1: 1000, meterP2: 0, p1XPx: -24, p2XPx: 24)
    }

    /// 4+1+40+3+100+3+100+3+100+6+80 = 440
    static func rook() -> KitScript {
        var build = PairBuilder()
        build.hold(p1: KitMotion.walkForward(facingRight: true), ticks: 4)
        build.hold(p1: KitMotion.toss(), ticks: 1)
        build.hold(ticks: 40)
        build.p1Only(KitMotion.qcf(.lightPunch, facingRight: true))
        build.hold(ticks: 100)
        build.p1Motion(KitMotion.qcf(.heavyPunch, facingRight: true), p2Button: .lightPunch)
        build.hold(ticks: 100)
        build.p1Motion(KitMotion.qcb(.lightPunch, facingRight: true), p2Button: .lightPunch)
        build.hold(ticks: 100)
        build.p1Only(KitMotion.super236(.lightKick, facingRight: true))
        build.hold(ticks: 80)
        return KitScript(frames: build.frames, meterP1: 1000, meterP2: 0, p1XPx: -18, p2XPx: 18)
    }
}
