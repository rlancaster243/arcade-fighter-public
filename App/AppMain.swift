import AppLogic
import FightCore
import SpriteKit
import SwiftUI

@main
struct ArcadeFighterApp: App {
    var body: some Scene {
        WindowGroup {
            GameRootView()
                .frame(minWidth: 768, minHeight: 432)
        }
    }
}

struct GameRootView: View {
    @State private var snapshot = SimulationBootstrap.greyboxMatch(seed: 0xAFC)

    var body: some View {
        SpriteView(scene: makeScene())
            .ignoresSafeArea()
            .onAppear { tickRender() }
    }

    private func makeScene() -> SKScene {
        let scene = GreyboxScene(size: CGSize(width: 384, height: 216))
        scene.scaleMode = .resizeFill
        scene.snapshot = snapshot
        return scene
    }

    private func tickRender() {
        var sim = Simulation()
        sim.step(inputs: [InputFrame(), InputFrame()], snapshot: &snapshot)
    }
}