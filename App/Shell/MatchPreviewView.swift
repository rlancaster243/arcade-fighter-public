import AppLogic
import FightCore
import SpriteKit
import SwiftUI

/// Letterboxed greybox preview during menu in-match state (kept small for Swift type-checker).
struct MatchPreviewView: View {
    let snapshot: GameSnapshot
    /// Bundle each slot actually loaded; drives which sprite sheet the scene draws.
    let contentIDs: [String]
    let viewWidth: Int
    let viewHeight: Int
    let wantsFullscreen: Bool
    let windowIntegerScale: Int
    var onAtlasLoadNotice: ((String) -> Void)?

    @State private var scene = GreyboxScene(size: CGSize(width: 384, height: 216))
    @State private var atlasSlotIDs: [String?] = []

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
                scene.contentIDs = contentIDs
                atlasSlotIDs = slotIDs(fighterIDs: snapshot.fighterIDs, contentIDs: contentIDs)
                scene.snapshot = snapshot
                scene.revalidateAtlases()
            }
            .onChange(of: snapshot) { _, newValue in
                scene.onAtlasLoadNotice = onAtlasLoadNotice
                scene.snapshot = newValue
                revalidateIfSlotsChanged(fighterIDs: newValue.fighterIDs, contentIDs: contentIDs)
            }
            .onChange(of: contentIDs) { _, newValue in
                scene.contentIDs = newValue
                revalidateIfSlotsChanged(fighterIDs: snapshot.fighterIDs, contentIDs: newValue)
            }
    }

    private func slotIDs(fighterIDs: [String], contentIDs: [String]) -> [String?] {
        FighterAtlasRouting.atlasIDs(fighterIDs: fighterIDs, contentIDs: contentIDs)
    }

    private func revalidateIfSlotsChanged(fighterIDs: [String], contentIDs: [String]) {
        let slots = slotIDs(fighterIDs: fighterIDs, contentIDs: contentIDs)
        guard slots != atlasSlotIDs else { return }
        atlasSlotIDs = slots
        scene.revalidateAtlases()
    }
}