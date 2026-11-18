import AppLogic
import FightCore
import SpriteKit
import SwiftUI

/// Letterboxed greybox preview during menu in-match state (kept small for Swift type-checker).
struct MatchPreviewView: View {
    let snapshot: GameSnapshot
    let viewWidth: Int
    let viewHeight: Int
    let wantsFullscreen: Bool
    let windowIntegerScale: Int
    var onAtlasLoadNotice: ((String) -> Void)?

    @State private var scene = GreyboxScene(size: CGSize(width: 384, height: 216))

    var body: some View {
        let forcedScale = wantsFullscreen ? nil : windowIntegerScale
        let viewport = DisplayLayout.viewport(
            viewWidth: viewWidth,
            viewHeight: viewHeight,
            forcedScale: forcedScale
        )
        let contentW = CGFloat(viewport.contentWidth)
        let contentH = CGFloat(viewport.contentHeight)
        let posX = CGFloat(viewport.offsetX) + contentW / 2
        let posY = CGFloat(viewport.offsetY) + contentH / 2
        SpriteView(scene: scene)
            #if os(iOS)
            .interpolation(.none)
            #endif
            .frame(width: contentW, height: contentH)
            .position(x: posX, y: posY)
            .onAppear {
                scene.scaleMode = .resizeFill
                scene.onAtlasLoadNotice = onAtlasLoadNotice
                scene.snapshot = snapshot
            }
            .onChange(of: snapshot) { _, newValue in
                scene.onAtlasLoadNotice = onAtlasLoadNotice
                scene.snapshot = newValue
            }
    }
}