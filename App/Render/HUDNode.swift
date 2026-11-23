import AppKit
import AppLogic
import FightCore
import SpriteKit

/// In-match HUD in an early-2000s 2D-fighter style: bevelled gradient bars, a red recent-damage
/// trail, a glowing full super meter, and 2×-density outlined text. Textures are generated once
/// and cached; per frame only sprite widths, glow alpha and changed label strings are touched.
final class HUDNode: SKNode {
    private let p1Health = HUDBar(frame: HUDLayout.p1HealthBarFrame(), alignLeft: true, style: .health)
    private let p2Health = HUDBar(frame: HUDLayout.p2HealthBarFrame(), alignLeft: false, style: .health)
    private let p1Meter = HUDBar(frame: HUDLayout.p1MeterBarFrame(), alignLeft: true, style: .meter)
    private let p2Meter = HUDBar(frame: HUDLayout.p2MeterBarFrame(), alignLeft: false, style: .meter)
    private let timerLabel = HUDOutlinedLabel(fontNamed: "Menlo-Bold", fontSize: 12)
    private let roundLabel = HUDOutlinedLabel(fontNamed: "Menlo-Bold", fontSize: 8)
    private var p1Trail = HUDDamageTrail()
    private var p2Trail = HUDDamageTrail()

    override init() {
        super.init()
        zPosition = 1000
        timerLabel.verticalAlignmentMode = .center
        timerLabel.horizontalAlignmentMode = .center
        roundLabel.verticalAlignmentMode = .top
        roundLabel.horizontalAlignmentMode = .center

        let round = HUDLayout.timerFrame()
        timerLabel.position = CGPoint(x: CGFloat(round.x + round.w / 2), y: CGFloat(round.y + round.h / 2))
        roundLabel.position = CGPoint(
            x: CGFloat(SceneConstants.width / 2),
            y: CGFloat(HUDLayout.roundLabelTopY())
        )
        for node in [p1Health, p2Health, p1Meter, p2Meter, timerLabel, roundLabel] as [SKNode] {
            addChild(node)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    /// `tick` is the render-side effects clock, so the damage trail drains even after the sim stops.
    func apply(snapshot: GameSnapshot, tick: Int32) {
        let model = HUDLayout.model(from: snapshot)
        let p1Shown = p1Trail.update(current: model.p1Health, tick: tick)
        let p2Shown = p2Trail.update(current: model.p2Health, tick: tick)
        let healthW = HUDLayout.p1HealthBarFrame().w
        let meterW = HUDLayout.p1MeterBarFrame().w

        p1Health.update(
            fillWidth: CGFloat(HUDLayout.filledWidth(current: model.p1Health, cap: model.p1HealthCap, barWidth: healthW)),
            trailWidth: CGFloat(HUDLayout.filledWidth(current: p1Shown, cap: model.p1HealthCap, barWidth: healthW)),
            glow: 0
        )
        p2Health.update(
            fillWidth: CGFloat(HUDLayout.filledWidth(current: model.p2Health, cap: model.p2HealthCap, barWidth: healthW)),
            trailWidth: CGFloat(HUDLayout.filledWidth(current: p2Shown, cap: model.p2HealthCap, barWidth: healthW)),
            glow: 0
        )
        // Slow, low-amplitude pulse (about 0.5 Hz) so a full meter reads without flashing.
        let pulse = CGFloat(0.55) + CGFloat(0.25) * CGFloat(sin(Double(tick) * 0.05))
        p1Meter.update(
            fillWidth: CGFloat(HUDLayout.filledWidth(current: model.p1Meter, cap: model.meterCap, barWidth: meterW)),
            trailWidth: nil,
            glow: model.meterCap > 0 && model.p1Meter >= model.meterCap ? pulse : 0
        )
        p2Meter.update(
            fillWidth: CGFloat(HUDLayout.filledWidth(current: model.p2Meter, cap: model.meterCap, barWidth: meterW)),
            trailWidth: nil,
            glow: model.meterCap > 0 && model.p2Meter >= model.meterCap ? pulse : 0
        )

        timerLabel.text = String(model.timerSeconds)
        roundLabel.text = "R\(model.roundNumber) \(model.p1RoundsWon)-\(model.p2RoundsWon)"
    }
}

/// One bar: dark frame, translucent bevelled backing, optional damage trail, gradient fill and,
/// for the meter, an additive glow. Geometry is placed once; `update` only resizes.
private final class HUDBar: SKNode {
    enum Style { case health, meter }

    private let trail: SKSpriteNode?
    private let fill: SKSpriteNode
    private let glow: SKSpriteNode?
    private var lastFill: CGFloat = -1
    private var lastTrail: CGFloat = -1
    private var lastGlow: CGFloat = -1

    init(frame: IntRect, alignLeft: Bool, style: Style) {
        let w = CGFloat(frame.w)
        let h = CGFloat(frame.h)
        let x = CGFloat(frame.x)
        let y = CGFloat(frame.y)
        let anchor = alignLeft ? CGPoint(x: 0, y: 0) : CGPoint(x: 1, y: 0)
        let base = alignLeft ? CGPoint(x: x, y: y) : CGPoint(x: x + w, y: y)
        let heightPx = Int(frame.h) * 2

        let border = SKSpriteNode(color: HUDPalette.frame, size: CGSize(width: w + 2, height: h + 2))
        border.anchorPoint = anchor
        border.position = alignLeft ? CGPoint(x: x - 1, y: y - 1) : CGPoint(x: x + w + 1, y: y - 1)
        border.zPosition = 0

        let back = SKSpriteNode(texture: HUDTextures.backing(heightPx: heightPx), size: CGSize(width: w, height: h))
        back.anchorPoint = anchor
        back.position = base
        back.zPosition = 1

        let fillTexture = style == .health
            ? HUDTextures.gradient(.healthFill, heightPx: heightPx)
            : HUDTextures.gradient(.meterFill, heightPx: heightPx)
        fill = SKSpriteNode(texture: fillTexture, size: CGSize(width: 0, height: h))
        fill.anchorPoint = anchor
        fill.position = base
        fill.zPosition = 3

        if style == .health {
            let t = SKSpriteNode(
                texture: HUDTextures.gradient(.damageTrail, heightPx: heightPx),
                size: CGSize(width: 0, height: h)
            )
            t.anchorPoint = anchor
            t.position = base
            t.zPosition = 2
            trail = t
        } else {
            trail = nil
        }

        if style == .meter {
            let g = SKSpriteNode(texture: HUDTextures.glow, size: CGSize(width: w + 12, height: h + 10))
            g.position = CGPoint(x: x + w / 2, y: y + h / 2)
            g.blendMode = .add
            g.zPosition = -1
            g.alpha = 0
            g.isHidden = true
            glow = g
        } else {
            glow = nil
        }

        super.init()
        for node in [glow, border, back, trail, fill] as [SKNode?] {
            if let node { addChild(node) }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func update(fillWidth: CGFloat, trailWidth: CGFloat?, glow glowAlpha: CGFloat) {
        let fillChanged = fillWidth != lastFill
        if fillChanged {
            lastFill = fillWidth
            fill.size.width = fillWidth
        }
        if let trail, let trailWidth, trailWidth != lastTrail || fillChanged {
            lastTrail = trailWidth
            // Only visible past the fill edge; hide when there is no recent damage.
            trail.size.width = trailWidth
            trail.isHidden = trailWidth <= fillWidth
        }
        if let glow, glowAlpha != lastGlow {
            lastGlow = glowAlpha
            glow.alpha = glowAlpha
            glow.isHidden = glowAlpha <= 0
        }
    }
}

/// Text rendered at 2× font size and scaled by 0.5 so it stays sharp under the window's integer
/// upscale, with a 1-texel dark outline and a one-pixel drop shadow.
private final class HUDOutlinedLabel: SKNode {
    private let main: SKLabelNode
    private let dark: [SKLabelNode]
    private var current = ""

    var text: String {
        get { current }
        set {
            guard newValue != current else { return }
            current = newValue
            main.text = newValue
            for label in dark { label.text = newValue }
        }
    }

    var verticalAlignmentMode: SKLabelVerticalAlignmentMode = .baseline {
        didSet { allLabels.forEach { $0.verticalAlignmentMode = verticalAlignmentMode } }
    }

    var horizontalAlignmentMode: SKLabelHorizontalAlignmentMode = .center {
        didSet { allLabels.forEach { $0.horizontalAlignmentMode = horizontalAlignmentMode } }
    }

    private var allLabels: [SKLabelNode] { dark + [main] }

    init(fontNamed: String, fontSize: CGFloat) {
        func makeLabel(_ color: NSColor, dx: CGFloat, dy: CGFloat, z: CGFloat) -> SKLabelNode {
            let label = SKLabelNode(fontNamed: fontNamed)
            label.fontSize = fontSize * 2
            label.fontColor = color
            label.position = CGPoint(x: dx, y: dy)
            label.zPosition = z
            return label
        }
        main = makeLabel(HUDPalette.text, dx: 0, dy: 0, z: 2)
        // Offsets are in 2× label space: 1 unit = half a scene pixel.
        var layers = [makeLabel(HUDPalette.textShadow, dx: 2, dy: -2, z: 0)]
        let outline: [(CGFloat, CGFloat)] = [(-1, -1), (1, -1), (-1, 1), (1, 1)]
        for (dx, dy) in outline {
            layers.append(makeLabel(HUDPalette.frame, dx: dx, dy: dy, z: 1))
        }
        dark = layers
        super.init()
        setScale(0.5)
        for label in dark + [main] { addChild(label) }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }
}

/// Runtime-generated gradient textures (CGContext → SKTexture), built once and cached. They are
/// narrow strips stretched horizontally by their sprites, so bilinear filtering only softens the
/// vertical ramp and never the bar's left/right edge.
private enum HUDTextures {
    enum Kind: Int { case healthFill, meterFill, damageTrail }

    private static var cache: [Int: SKTexture] = [:]

    static func gradient(_ kind: Kind, heightPx: Int) -> SKTexture {
        cached(key: kind.rawValue * 1000 + heightPx) {
            switch kind {
            case .healthFill:
                return strip(heightPx: heightPx, stops: [
                    (0.0, rgb(1.00, 0.97, 0.70)), (0.30, rgb(1.00, 0.84, 0.22)),
                    (0.65, rgb(0.96, 0.62, 0.08)), (1.0, rgb(0.72, 0.36, 0.04)),
                ], highlight: 0.55, shadow: 0.35)
            case .meterFill:
                return strip(heightPx: heightPx, stops: [
                    (0.0, rgb(0.80, 0.95, 1.00)), (0.30, rgb(0.30, 0.68, 1.00)),
                    (0.70, rgb(0.12, 0.38, 0.92)), (1.0, rgb(0.05, 0.16, 0.60)),
                ], highlight: 0.55, shadow: 0.35)
            case .damageTrail:
                return strip(heightPx: heightPx, stops: [
                    (0.0, rgb(1.00, 0.50, 0.42)), (0.35, rgb(0.92, 0.18, 0.14)),
                    (1.0, rgb(0.50, 0.04, 0.05)),
                ], highlight: 0.30, shadow: 0.30)
            }
        }
    }

    /// Dark translucent backing with a faint top bevel and bottom shadow.
    static func backing(heightPx: Int) -> SKTexture {
        cached(key: 9000 + heightPx) {
            strip(heightPx: heightPx, stops: [
                (0.0, rgb(0.20, 0.20, 0.30, 0.78)), (1.0, rgb(0.03, 0.03, 0.08, 0.78)),
            ], highlight: 0.18, shadow: 0.40)
        }
    }

    /// Soft elliptical halo for the full super meter (drawn additively).
    static let glow: SKTexture = {
        let size = 32
        return draw(width: size, height: size) { ctx in
            let space = CGColorSpaceCreateDeviceRGB()
            let colors = [rgb(0.55, 0.85, 1.0, 0.95), rgb(0.25, 0.60, 1.0, 0.40), rgb(0.10, 0.30, 1.0, 0.0)]
                .map { $0.cgColor } as CFArray
            guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.45, 1]) else { return }
            let c = CGPoint(x: CGFloat(size) / 2, y: CGFloat(size) / 2)
            ctx.drawRadialGradient(
                gradient, startCenter: c, startRadius: 0, endCenter: c,
                endRadius: CGFloat(size) / 2, options: []
            )
        }
    }()

    private static func cached(key: Int, _ make: () -> SKTexture) -> SKTexture {
        if let t = cache[key] { return t }
        let t = make()
        cache[key] = t
        return t
    }

    private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }

    /// A 4-px-wide vertical gradient with a 2-texel (1 scene px) top highlight and bottom shadow.
    private static func strip(
        heightPx: Int,
        stops: [(CGFloat, NSColor)],
        highlight: CGFloat,
        shadow: CGFloat
    ) -> SKTexture {
        draw(width: 4, height: heightPx) { ctx in
            let space = CGColorSpaceCreateDeviceRGB()
            let colors = stops.map { $0.1.cgColor } as CFArray
            let locations = stops.map { $0.0 }
            let h = CGFloat(heightPx)
            if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: locations) {
                // CG origin is bottom-left: location 0 is the top edge.
                ctx.drawLinearGradient(
                    gradient, start: CGPoint(x: 0, y: h), end: CGPoint(x: 0, y: 0), options: []
                )
            }
            ctx.setFillColor(NSColor(white: 1, alpha: highlight).cgColor)
            ctx.fill(CGRect(x: 0, y: h - 2, width: 4, height: 2))
            ctx.setFillColor(NSColor(white: 0, alpha: shadow).cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 2))
        }
    }

    private static func draw(width: Int, height: Int, _ body: (CGContext) -> Void) -> SKTexture {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return SKTexture()
        }
        body(ctx)
        guard let image = ctx.makeImage() else { return SKTexture() }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .linear
        return texture
    }
}

/// HUD colours: gold health, red damage trail, blue meter, dark navy frame.
enum HUDPalette {
    static let health = NSColor(srgbRed: 1.0, green: 0.80, blue: 0.16, alpha: 1)
    static let healthTrack = NSColor(srgbRed: 0.62, green: 0.08, blue: 0.08, alpha: 1)
    static let meter = NSColor(srgbRed: 0.20, green: 0.55, blue: 1.0, alpha: 1)
    static let meterTrack = NSColor(srgbRed: 0.06, green: 0.08, blue: 0.20, alpha: 1)
    static let frame = NSColor(srgbRed: 0.04, green: 0.03, blue: 0.08, alpha: 1)
    static let text = NSColor(srgbRed: 1.0, green: 0.97, blue: 0.88, alpha: 1)
    static let textShadow = NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.55)
}
