import AppKit
import AppLogic
import FightCore
import SpriteKit

final class SparkBurst: SKNode {
    private let spawnTick: Int32
    private var pieces: [(node: SKSpriteNode, angle: CGFloat)] = []

    /// PS1-style starburst: 8 chunky shards that fly out and fade over `SparkLife.ticks` sim ticks.
    init(kind: SparkKind, spawnTick: Int32) {
        self.spawnTick = spawnTick
        super.init()
        let colors: [NSColor] = kind == .hit
            ? [NSColor(srgbRed: 1, green: 0.95, blue: 0.6, alpha: 1), NSColor(srgbRed: 1, green: 0.55, blue: 0.1, alpha: 1)]
            : [.white, NSColor(srgbRed: 0.55, green: 0.8, blue: 1, alpha: 1)]
        let core = SKSpriteNode(color: colors[0], size: CGSize(width: 6, height: 6))
        core.zRotation = .pi / 4
        addChild(core)
        for i in 0..<8 {
            let piece = SKSpriteNode(color: colors[i % 2], size: CGSize(width: i % 2 == 0 ? 5 : 3, height: i % 2 == 0 ? 5 : 3))
            let angle = CGFloat(i) * (.pi / 4) + .pi / 8
            addChild(piece)
            pieces.append((piece, angle))
        }
        _ = apply(tick: spawnTick)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    /// Positions shards for the current sim tick; false once the spark has finished.
    func apply(tick: Int32) -> Bool {
        guard let state = SparkLife.state(ageTicks: tick - spawnTick) else { return false }
        alpha = CGFloat(state.alpha)
        for (node, angle) in pieces {
            node.position = CGPoint(x: cos(angle) * state.radius, y: sin(angle) * state.radius)
        }
        return true
    }
}

enum ShakeState {
    static func offset(tick: Int32, amplitude: Int32) -> CGPoint {
        if amplitude <= 0 { return .zero }
        let phase = tick % 4
        switch phase {
        case 0: return CGPoint(x: CGFloat(amplitude), y: 0)
        case 1: return CGPoint(x: CGFloat(-amplitude), y: 0)
        case 2: return CGPoint(x: 0, y: CGFloat(amplitude))
        default: return CGPoint(x: 0, y: CGFloat(-amplitude))
        }
    }
}