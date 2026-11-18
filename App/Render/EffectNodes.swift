import AppKit
import AppLogic
import FightCore
import SpriteKit

final class SparkBurst: SKNode {
    private var remaining: Int32 = 8

    init(kind: SparkKind) {
        super.init()
        let color: NSColor = kind == .hit ? .orange : .white
        for i in 0..<6 {
            let piece = SKSpriteNode(color: color, size: CGSize(width: 3, height: 3))
            let angle = CGFloat(i) * (.pi / 3)
            piece.position = CGPoint(x: cos(angle) * 6, y: sin(angle) * 6)
            addChild(piece)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func tick() -> Bool {
        remaining -= 1
        alpha = CGFloat(remaining) / 8.0
        return remaining > 0
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