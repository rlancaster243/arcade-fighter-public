import AppLogic
import FightCore
import ImageIO
import SpriteKit

/// Reads one immutable `GameSnapshot` per frame; does not mutate core state.
final class GreyboxScene: SKScene {
    var snapshot: GameSnapshot = SimulationBootstrap.greyboxMatch() {
        didSet {
            fxInbox.receive(snapshot)
            syncAtlasesIfNeeded()
        }
    }
    /// Hit/block events from every assigned snapshot (see FXEventInbox).
    private var fxInbox = FXEventInbox()

    private let letterboxNode = SKNode()
    private let arenaNode = SKNode()
    private let hud = HUDNode()
    private let ground = SKSpriteNode(color: .darkGray, size: .zero)
    private let projectileLayer = SKNode()
    private var atlases: [String: SpriteAtlas] = [:]
    private var loadedAtlasIDs: Set<String> = []
    private var atlasFailureNotified: Set<String> = []
    private var fighterNodes: [SKNode] = []
    private var activeSparks: [SparkBurst] = []
    private var hitFlash = HitFlashTracker()
    private var fxClock = FXClock()
    private var lastUpdateTime: TimeInterval?
    private var shakeTicks: Int32 = 0
    private var shakeAmp: Int32 = 0
    private var renderTick: Int32 = 0
    private var contentOffset = CGPoint.zero
    var onAtlasLoadNotice: ((String) -> Void)?
    /// Stage whose background layers draw behind the arena; empty draws none.
    var stageID: String = "" {
        didSet { if stageID != oldValue { loadStageLayers() } }
    }
    private let stageNode = SKNode()
    private var stageLayers: [(node: SKSpriteNode, parallaxQ8: Int32)] = []
    /// Bundle each slot actually loaded (see `FighterAtlasRouting`); empty until a match starts.
    var contentIDs: [String] = []

    private var slotAtlasIDs: [String?] {
        FighterSkin.sheetNames(
            atlasIDs: FighterAtlasRouting.atlasIDs(fighterIDs: snapshot.fighterIDs, contentIDs: contentIDs))
    }

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
        projectileLayer.zPosition = 40
        arenaNode.addChild(projectileLayer)
        stageNode.zPosition = -100
        letterboxNode.addChild(stageNode)
        letterboxNode.addChild(arenaNode)
        letterboxNode.addChild(hud)
        addChild(letterboxNode)
        applyViewLayout(to: view)
        syncAtlasesIfNeeded()
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
        // Don't assign `size` here. Under `.resizeFill` SpriteKit keeps it equal to the view's
        // bounds; writing the Int32-truncated size makes SpriteKit snap it back on fractional
        // bounds, re-entering didChangeSize until the stack overflows.
        let scale = CGFloat(layout.scale)
        letterboxNode.setScale(scale)
        letterboxNode.position = contentOffset
        view.layer?.magnificationFilter = .linear
    }

    private func loadStageLayers() {
        stageNode.removeAllChildren()
        stageLayers = []
        guard !stageID.isEmpty else { ground.isHidden = false; return }
        do {
            for spec in try StageArt.layers(stageID: stageID, fromFile: #filePath) {
                guard let source = CGImageSourceCreateWithURL(spec.imageURL as CFURL, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                    onAtlasLoadNotice?("Stage layer \(spec.id) for \(stageID) failed to decode")
                    continue
                }
                let texture = SKTexture(cgImage: image)
                texture.filteringMode = .linear
                texture.usesMipmaps = true
                let logical = StageArt.logicalSize(
                    pixelWidth: image.width, pixelHeight: image.height, texelScale: spec.texelScale)
                let node = SKSpriteNode(
                    texture: texture,
                    size: CGSize(width: CGFloat(logical.width), height: CGFloat(logical.height))
                )
                node.anchorPoint = .zero
                node.zPosition = CGFloat(spec.zOrder)
                stageNode.addChild(node)
                stageLayers.append((node, spec.parallaxQ8))
            }
        } catch {
            onAtlasLoadNotice?("Stage \(stageID) art failed: \(error.localizedDescription)")
        }
        // The painted floor replaces the debug floor line.
        ground.isHidden = !stageLayers.isEmpty
    }

    /// Re-run atlas loads after `onAtlasLoadNotice` is attached (e.g. post-`didMove`).
    func revalidateAtlases() {
        loadedAtlasIDs = []
        atlasFailureNotified = []
        syncAtlasesIfNeeded()
    }

    private func syncAtlasesIfNeeded() {
        let ids = Set(slotAtlasIDs.compactMap { $0 })
        guard ids != loadedAtlasIDs else { return }
        for id in ids where !loadedAtlasIDs.contains(id) {
            let bundleID = FighterSkin.bundleID(ofSheet: id)
            let dir = ContentPaths.fighterDirectory(bundleID, fromFile: #filePath)
            var png = dir.appendingPathComponent("\(id).png")
            if !FileManager.default.fileExists(atPath: png.path) { // no alt costume shipped: normal sheet
                png = dir.appendingPathComponent("\(bundleID).png")
            }
            let json = dir.appendingPathComponent("sheet.json")
            do {
                let atlas = try SpriteAtlas(sheetPNG: png, sheetJSON: json)
                atlases[id] = atlas
            } catch {
                guard !atlasFailureNotified.contains(id) else { continue }
                atlasFailureNotified.insert(id)
                onAtlasLoadNotice?("Sprite sheet for “\(id)” failed: \(error.localizedDescription)")
            }
        }
        loadedAtlasIDs = ids
    }

    override func update(_ currentTime: TimeInterval) {
        renderTick &+= 1
        fxClock.advance(snapshotTick: snapshot.tick, dt: lastUpdateTime.map { currentTime - $0 } ?? 0)
        lastUpdateTime = currentTime
        spawnCombatFXIfNeeded() // before syncFighters so a heavy-hit flash shows on the hit's own frame
        syncFighters()
        syncProjectiles()
        hud.apply(snapshot: snapshot, tick: fxClock.now)
        applyCameraAndShake()
        activeSparks = activeSparks.filter { spark in
            guard spark.apply(tick: fxClock.now) else {
                spark.removeFromParent() // finished bursts otherwise pile up in arenaNode
                return false
            }
            return true
        }
    }

    /// Tick for looping pose animation. It follows the sim so fighters hold still under the pause
    /// card; after the match ends the sim stops for good, so the win pose runs on the FX clock.
    private var poseTick: Int32 {
        snapshot.rules.matchOver ? fxClock.now : snapshot.tick
    }

    private func syncFighters() {
        while fighterNodes.count < snapshot.fighters.count {
            let placeholder = SKNode()
            arenaNode.addChild(placeholder)
            fighterNodes.append(placeholder)
        }
        ground.size = CGSize(width: CGFloat(SceneConstants.width), height: 4)
        ground.position = CGPoint(x: 0, y: CGFloat(WorldToScene.floorY))

        let slots = slotAtlasIDs
        for (index, fighter) in snapshot.fighters.enumerated() {
            let container = fighterNodes[index]
            container.removeAllChildren()
            let atlasID: String? = slots.indices.contains(index) ? slots[index] : "greybox"
            let candidates = SpriteSelection.frameCandidates(for: fighter, tick: poseTick)
            let sprite: SKNode
            if let atlasID, let atlas = atlases[atlasID],
               let node = candidates.lazy.compactMap({ atlas.spriteNode(named: $0) }).first {
                sprite = node
            } else {
                let fallback = SKSpriteNode(color: index == 0 ? .cyan : .magenta, size: CGSize(width: 40, height: 90))
                fallback.anchorPoint = CGPoint(x: 0.5, y: 0)
                sprite = fallback
            }
            let p = WorldToScene.point(simX: fighter.position.x.raw, simY: fighter.position.y.raw)
            container.position = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
            sprite.xScale = fighter.facingRight ? 1 : -1
            let flash = Float(hitFlash.blend(slot: index, tick: fxClock.now))
            if flash > 0, let flashed = sprite as? SKSpriteNode { // heavy-hit flash: this fighter only
                flashed.shader = HitFlashShader.shader(slot: index, blend: flash)
            }
            container.addChild(sprite)
        }
    }

    private func syncProjectiles() {
        projectileLayer.removeAllChildren()
        let slots = slotAtlasIDs
        for p in snapshot.projectiles where p.active {
            let index = Int(p.owner.rawValue)
            let atlasID = slots.indices.contains(index) ? slots[index] : nil
            let frame = "proj_\((max(snapshot.tick, 0) / 4) % 2)"
            let node: SKNode
            if let atlasID, let atlas = atlases[atlasID], let sprite = atlas.spriteNode(named: frame) {
                sprite.xScale = p.velocity.x.raw >= 0 ? 1 : -1
                node = sprite
            } else {
                node = SKSpriteNode(color: .orange, size: CGSize(width: CGFloat(p.hitbox.w), height: CGFloat(p.hitbox.h)))
            }
            let c = WorldToScene.projectileCentre(p)
            node.position = CGPoint(x: CGFloat(c.x), y: CGFloat(c.y))
            projectileLayer.addChild(node)
        }
    }

    private func spawnCombatFXIfNeeded() {
        let events = fxInbox.drain()
        guard !events.isEmpty else { return }
        var fxSnapshot = snapshot
        fxSnapshot.events = events
        let amp = CombatPresentation.shakeAmplitude(for: fxSnapshot)
        if amp > 0 {
            shakeAmp = amp
            shakeTicks = 12
        }
        for spark in CombatPresentation.sparks(from: fxSnapshot) {
            if spark.heavy { hitFlash.trigger(slot: spark.defenderIndex, tick: fxClock.now) }
            let burst = SparkBurst(request: spark, spawnTick: fxClock.now)
            burst.position = CGPoint(x: CGFloat(spark.worldX), y: CGFloat(spark.worldY))
            burst.zPosition = 50
            arenaNode.addChild(burst)
            activeSparks.append(burst)
        }
    }

    private func applyCameraAndShake() {
        let cam = FightCameraMath.compute(snapshot: snapshot)
        var offset = CGPoint(x: CGFloat(-cam.scrollX), y: CGFloat(-cam.scrollY))
        if shakeTicks > 0 {
            let shake = ShakeState.offset(tick: renderTick, amplitude: shakeAmp)
            offset = CGPoint(x: offset.x + shake.x, y: offset.y + shake.y)
            shakeTicks -= 1
        }
        arenaNode.position = offset
        // Stage layers are one screen tall and composed to line up at scroll 0 (stage2's bells
        // sit inside the arches there), so they are drawn from their left edge. They do not take the shake: shifting them would uncover bare background along the screen edges.
        let distinct = Set(stageLayers.map(\.parallaxQ8))
        let farthest = distinct.count > 1 ? distinct.min() : nil
        for layer in stageLayers {
            let x = StageArt.layerOffsetX(scrollX: cam.scrollX, parallaxQ8: layer.parallaxQ8)
            // The farthest layer stays put vertically, or a high jump would show a strip of
            // background above it. A lone layer is the floor and must follow the arena.
            let y = layer.parallaxQ8 == farthest ? 0 : -(cam.scrollY * layer.parallaxQ8) / 256
            layer.node.position = CGPoint(x: CGFloat(x), y: CGFloat(y))
        }
        hud.position = .zero
    }
}