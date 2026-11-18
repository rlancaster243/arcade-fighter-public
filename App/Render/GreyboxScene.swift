import AppLogic
import FightCore
import SpriteKit

/// Reads one immutable `GameSnapshot` per frame; does not mutate core state.
final class GreyboxScene: SKScene {
    var snapshot: GameSnapshot = SimulationBootstrap.greyboxMatch()

    private let letterboxNode = SKNode()
    private let arenaNode = SKNode()
    private let hud = HUDNode()
    private let ground = SKSpriteNode(color: .darkGray, size: .zero)
    private var atlases: [String: SpriteAtlas] = [:]
    private var fighterNodes: [SKNode] = []
    private var activeSparks: [SparkBurst] = []
    private var lastProcessedTick: Int32 = -1
    private var shakeTicks: Int32 = 0
    private var shakeAmp: Int32 = 0
    private var renderTick: Int32 = 0
    private var contentOffset = CGPoint.zero

    override init(size: CGSize) {
        super.init(size: size)
        anchorPoint = CGPoint(x: 0, y: 0)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func didMove(to view: SKView) {
        backgroundColor = .init(white: 0.08, alpha: 1)
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 60

        ground.anchorPoint = CGPoint(x: 0, y: 0)
        ground.zPosition = -10
        arenaNode.addChild(ground)
        letterboxNode.addChild(arenaNode)
        letterboxNode.addChild(hud)
        addChild(letterboxNode)
        applyViewLayout(to: view)
        preloadAtlases()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        if let view {
            applyViewLayout(to: view)
        }
    }

    private func applyViewLayout(to view: SKView) {
        let layout = ViewScaleMath.largestIntegerScale(
            viewportWidth: Int32(view.bounds.width),
            viewportHeight: Int32(view.bounds.height)
        )
        contentOffset = CGPoint(x: CGFloat(layout.contentOffsetX), y: CGFloat(layout.contentOffsetY))
        size = CGSize(width: CGFloat(layout.viewportWidth), height: CGFloat(layout.viewportHeight))
        let scale = CGFloat(layout.scale)
        letterboxNode.setScale(scale)
        letterboxNode.position = contentOffset
        view.layer?.magnificationFilter = .nearest
    }

    private func preloadAtlases() {
        let root = ContentPaths.repoRoot(fromFile: #filePath)
        for id in Set(snapshot.fighterIDs) {
            let dir = root.appendingPathComponent("Content/Fighters/\(id)", isDirectory: true)
            let png = dir.appendingPathComponent("\(id).png")
            let json = dir.appendingPathComponent("sheet.json")
            if let atlas = try? SpriteAtlas(sheetPNG: png, sheetJSON: json) {
                atlases[id] = atlas
            }
        }
    }

    override func update(_: TimeInterval) {
        renderTick &+= 1
        syncFighters()
        hud.apply(snapshot: snapshot)
        spawnCombatFXIfNeeded()
        applyCameraAndShake()
        activeSparks = activeSparks.filter { $0.tick() }
    }

    private func syncFighters() {
        while fighterNodes.count < snapshot.fighters.count {
            let placeholder = SKNode()
            arenaNode.addChild(placeholder)
            fighterNodes.append(placeholder)
        }
        ground.size = CGSize(width: CGFloat(SceneConstants.width), height: 4)
        ground.position = CGPoint(x: 0, y: 32)

        for (index, fighter) in snapshot.fighters.enumerated() {
            let container = fighterNodes[index]
            container.removeAllChildren()
            let fighterID = snapshot.fighterIDs.indices.contains(index) ? snapshot.fighterIDs[index] : "greybox"
            let frameName = SpriteSelection.frameName(for: fighter)
            let sprite: SKNode
            if let atlas = atlases[fighterID], let node = atlas.spriteNode(named: frameName) ?? atlas.spriteNode(named: "idle_0") {
                sprite = node
            } else {
                let fallback = SKSpriteNode(color: index == 0 ? .cyan : .magenta, size: CGSize(width: 40, height: 90))
                fallback.anchorPoint = CGPoint(x: 0.5, y: 0)
                sprite = fallback
            }
            let px = CGFloat(fighter.position.x.raw) / CGFloat(Fixed.scale) + CGFloat(SceneConstants.width / 2)
            let py = CGFloat(fighter.position.y.raw) / CGFloat(Fixed.scale) + 32
            container.position = CGPoint(x: px, y: py)
            sprite.xScale = fighter.facingRight ? 1 : -1
            container.addChild(sprite)
        }
    }

    private func spawnCombatFXIfNeeded() {
        guard snapshot.tick != lastProcessedTick else { return }
        lastProcessedTick = snapshot.tick
        let amp = CombatPresentation.shakeAmplitude(for: snapshot)
        if amp > 0 {
            shakeAmp = amp
            shakeTicks = 12
        }
        for spark in CombatPresentation.sparks(from: snapshot) {
            let burst = SparkBurst(kind: spark.kind)
            burst.position = CGPoint(x: CGFloat(spark.worldX), y: CGFloat(spark.worldY))
            burst.zPosition = 50
            arenaNode.addChild(burst)
            activeSparks.append(burst)
        }
    }

    private func applyCameraAndShake() {
        let cam = FightCameraMath.compute(snapshot: snapshot)
        var offset = CGPoint(x: CGFloat(-cam.scrollX), y: 0)
        if shakeTicks > 0 {
            offset = offset + ShakeState.offset(tick: renderTick, amplitude: shakeAmp)
            shakeTicks -= 1
        }
        arenaNode.position = offset
        hud.position = .zero
    }
}