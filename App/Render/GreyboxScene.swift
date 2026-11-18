import FightCore
import SpriteKit

/// Reads one immutable `GameSnapshot` per frame; does not mutate core state.
final class GreyboxScene: SKScene {
    var snapshot: GameSnapshot = SimulationBootstrap.greyboxMatch()

    override func didMove(to view: SKView) {
        backgroundColor = .init(white: 0.12, alpha: 1)
        anchorPoint = CGPoint(x: 0, y: 0)
    }

    override func update(_ currentTime: TimeInterval) {
        removeAllChildren()
        let ground = SKSpriteNode(color: .darkGray, size: CGSize(width: size.width, height: 4))
        ground.position = CGPoint(x: size.width / 2, y: 32)
        addChild(ground)

        for (index, fighter) in snapshot.fighters.enumerated() {
            let rect = SKSpriteNode(color: index == 0 ? .cyan : .magenta, size: CGSize(width: 40, height: 90))
            let px = CGFloat(fighter.position.x.raw) / CGFloat(Fixed.scale) + size.width / 2
            let py = CGFloat(fighter.position.y.raw) / CGFloat(Fixed.scale) + 32
            rect.position = CGPoint(x: px, y: py + 45)
            if !fighter.facingRight {
                rect.xScale = -1
            }
            addChild(rect)
        }
    }
}