import AppKit
import AppLogic
import FightCore
import SpriteKit

/// Runtime-generated glow textures (no Content files): white-on-clear so each sprite tints them with
/// `color` + `colorBlendFactor = 1`. Built once and shared by every spark.
enum EffectTextures {
    /// Soft radial falloff, bright centre to fully transparent rim.
    static let halo: SKTexture = make(width: 64, height: 64) { ctx, w, h in
        let space = CGColorSpaceCreateDeviceRGB()
        let colors = [
            CGColor(colorSpace: space, components: [1, 1, 1, 1])!,
            CGColor(colorSpace: space, components: [1, 1, 1, 0.45])!,
            CGColor(colorSpace: space, components: [1, 1, 1, 0.12])!,
            CGColor(colorSpace: space, components: [1, 1, 1, 0])!,
        ] as CFArray
        let locations: [CGFloat] = [0, 0.25, 0.6, 1]
        guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: locations) else { return }
        let centre = CGPoint(x: w / 2, y: h / 2)
        ctx.drawRadialGradient(gradient, startCenter: centre, startRadius: 0,
                               endCenter: centre, endRadius: w / 2, options: [])
    }

    /// Tapered ray, opaque at the left (spark origin), pointed and transparent at the right.
    static let streak: SKTexture = make(width: 32, height: 8) { ctx, w, h in
        let space = CGColorSpaceCreateDeviceRGB()
        let colors = [
            CGColor(colorSpace: space, components: [1, 1, 1, 1])!,
            CGColor(colorSpace: space, components: [1, 1, 1, 0])!,
        ] as CFArray
        guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else { return }
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 0, y: 0))
        ctx.addLine(to: CGPoint(x: w, y: h / 2))
        ctx.addLine(to: CGPoint(x: 0, y: h))
        ctx.closePath()
        ctx.clip()
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: h / 2), end: CGPoint(x: w, y: h / 2), options: [])
    }

    private static func make(width: Int, height: Int, draw: (CGContext, CGFloat, CGFloat) -> Void) -> SKTexture {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return SKTexture() }
        draw(ctx, CGFloat(width), CGFloat(height))
        guard let image = ctx.makeImage() else { return SKTexture() }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .linear
        return texture
    }
}

/// PS2-style spark: additive hot core, soft halo and short radiating streaks. Timed in sim ticks via
/// `SparkLife`; 12 sprites at most, all sharing two cached textures.
final class SparkBurst: SKNode {
    private let spawnTick: Int32
    private let halo = SKSpriteNode(texture: EffectTextures.halo)
    private let core = SKSpriteNode(texture: EffectTextures.halo)
    private var streaks: [(node: SKSpriteNode, angle: CGFloat)] = []

    private static let haloSize: CGFloat = 38 // logical px; sprites are ~100 tall
    private static let coreSize: CGFloat = 16
    private static let streakLength: CGFloat = 15
    private static let streakThickness: CGFloat = 3.5

    init(request: SparkRequest, spawnTick: Int32) {
        self.spawnTick = spawnTick
        super.init()
        let isHit = request.kind == .hit
        let coreColor = isHit ? NSColor(srgbRed: 1, green: 0.97, blue: 0.78, alpha: 1) : NSColor.white
        let haloColor = isHit ? NSColor(srgbRed: 1, green: 0.58, blue: 0.12, alpha: 1)
                              : NSColor(srgbRed: 0.35, green: 0.65, blue: 1, alpha: 1)
        let streakColors: [NSColor] = isHit
            ? [NSColor(srgbRed: 1, green: 0.92, blue: 0.45, alpha: 1), .white]
            : [NSColor(srgbRed: 0.72, green: 0.9, blue: 1, alpha: 1), .white]

        for (sprite, color) in [(halo, haloColor), (core, coreColor)] {
            sprite.color = color
            sprite.colorBlendFactor = 1
            sprite.blendMode = .add
            addChild(sprite)
        }
        halo.zPosition = 0
        core.zPosition = 2

        let angles = SparkShape.streakAngles(count: request.streakCount, seed: spawnTick)
        for (i, angle) in angles.enumerated() {
            let node = SKSpriteNode(texture: EffectTextures.streak)
            node.anchorPoint = CGPoint(x: 0, y: 0.5)
            node.color = streakColors[i % 2]
            node.colorBlendFactor = 1
            node.blendMode = .add
            node.zRotation = CGFloat(angle)
            node.zPosition = 1
            addChild(node)
            streaks.append((node, CGFloat(angle)))
        }
        setScale(CGFloat(request.scale))
        _ = apply(tick: spawnTick)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    /// Updates sprites for the current sim tick; false once the spark has finished.
    func apply(tick: Int32) -> Bool {
        let age = tick - spawnTick
        guard let state = SparkLife.state(ageTicks: age) else { return false }
        let t = CGFloat(age) / CGFloat(SparkLife.ticks)
        alpha = CGFloat(state.alpha)
        let radius = CGFloat(state.radius) // explicit CGFloat: CI's toolchain finds cos(CGFloat) * Double ambiguous
        let haloDiameter = SparkBurst.haloSize * (0.8 + 0.5 * t)
        halo.size = CGSize(width: haloDiameter, height: haloDiameter)
        let coreDiameter = SparkBurst.coreSize * (1 - 0.6 * t)
        core.size = CGSize(width: coreDiameter, height: coreDiameter)
        let length: CGFloat = SparkBurst.streakLength * (1 - 0.35 * t)
        for (node, angle) in streaks {
            let inner: CGFloat = radius * 0.6
            node.position = CGPoint(x: cos(angle) * inner, y: sin(angle) * inner)
            node.size = CGSize(width: length, height: SparkBurst.streakThickness)
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