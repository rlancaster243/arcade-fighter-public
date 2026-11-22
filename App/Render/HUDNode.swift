import AppKit
import AppLogic
import FightCore
import SpriteKit

final class HUDNode: SKNode {
    private let p1HealthBack = SKSpriteNode(color: .darkGray, size: .zero)
    private let p1HealthFill = SKSpriteNode(color: .green, size: .zero)
    private let p2HealthBack = SKSpriteNode(color: .darkGray, size: .zero)
    private let p2HealthFill = SKSpriteNode(color: .green, size: .zero)
    private let p1MeterBack = SKSpriteNode(color: .black, size: .zero)
    private let p1MeterFill = SKSpriteNode(color: .cyan, size: .zero)
    private let p2MeterBack = SKSpriteNode(color: .black, size: .zero)
    private let p2MeterFill = SKSpriteNode(color: .magenta, size: .zero)
    private let timerLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let roundLabel = SKLabelNode(fontNamed: "Menlo")

    override init() {
        super.init()
        zPosition = 1000
        timerLabel.fontSize = 12
        timerLabel.verticalAlignmentMode = .center
        timerLabel.horizontalAlignmentMode = .center
        roundLabel.fontSize = 8
        roundLabel.verticalAlignmentMode = .top
        roundLabel.horizontalAlignmentMode = .center
        for node in [
            p1HealthBack, p1HealthFill, p2HealthBack, p2HealthFill,
            p1MeterBack, p1MeterFill, p2MeterBack, p2MeterFill,
            timerLabel, roundLabel,
        ] {
            addChild(node)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func apply(snapshot: GameSnapshot) {
        let model = HUDLayout.model(from: snapshot)
        layoutBars(model: model)
        timerLabel.text = String(model.timerSeconds)
        let round = HUDLayout.timerFrame()
        timerLabel.position = CGPoint(x: CGFloat(round.x + round.w / 2), y: CGFloat(round.y + round.h / 2))
        roundLabel.text = "R\(model.roundNumber) \(model.p1RoundsWon)-\(model.p2RoundsWon)"
        roundLabel.position = CGPoint(
            x: CGFloat(SceneConstants.width / 2),
            y: CGFloat(HUDLayout.roundLabelTopY())
        )
    }

    private func layoutBars(model: HUDModel) {
        placeBarPair(
            back: p1HealthBack,
            fill: p1HealthFill,
            frame: HUDLayout.p1HealthBarFrame(),
            current: model.p1Health,
            cap: model.p1HealthCap,
            fillColor: .green,
            alignLeft: true
        )
        placeBarPair(
            back: p2HealthBack,
            fill: p2HealthFill,
            frame: HUDLayout.p2HealthBarFrame(),
            current: model.p2Health,
            cap: model.p2HealthCap,
            fillColor: .green,
            alignLeft: false
        )
        placeBarPair(
            back: p1MeterBack,
            fill: p1MeterFill,
            frame: HUDLayout.p1MeterBarFrame(),
            current: model.p1Meter,
            cap: model.meterCap,
            fillColor: .cyan,
            alignLeft: true
        )
        placeBarPair(
            back: p2MeterBack,
            fill: p2MeterFill,
            frame: HUDLayout.p2MeterBarFrame(),
            current: model.p2Meter,
            cap: model.meterCap,
            fillColor: .yellow,
            alignLeft: false
        )
    }

    private func placeBarPair(
        back: SKSpriteNode,
        fill: SKSpriteNode,
        frame: IntRect,
        current: Int32,
        cap: Int32,
        fillColor: NSColor,
        alignLeft: Bool
    ) {
        let w = CGFloat(frame.w)
        let h = CGFloat(frame.h)
        let x = CGFloat(frame.x)
        let y = CGFloat(frame.y)
        back.color = .darkGray
        back.size = CGSize(width: w, height: h)
        back.anchorPoint = alignLeft ? CGPoint(x: 0, y: 0) : CGPoint(x: 1, y: 0)
        back.position = alignLeft ? CGPoint(x: x, y: y) : CGPoint(x: x + w, y: y)

        let filled = HUDLayout.filledWidth(current: current, cap: cap, barWidth: frame.w)
        let fw = CGFloat(filled)
        fill.color = fillColor
        fill.size = CGSize(width: fw, height: h)
        fill.anchorPoint = alignLeft ? CGPoint(x: 0, y: 0) : CGPoint(x: 1, y: 0)
        fill.position = back.position
    }
}