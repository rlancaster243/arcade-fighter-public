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
    @StateObject private var input = InputCoordinator()
    @State private var snapshot = SimulationBootstrap.greyboxMatch(seed: 0xAFC)

    var body: some View {
        ZStack(alignment: .topLeading) {
            SpriteView(scene: makeScene())
                .ignoresSafeArea()
            InputSettingsOverlay(input: input)
                .padding(12)
        }
        .onAppear { tickRender() }
        .sheet(isPresented: $input.showKeyTest) {
            KeyTestScreen(input: input)
        }
    }

    private func makeScene() -> SKScene {
        let scene = GreyboxScene(size: CGSize(width: 384, height: 216))
        scene.scaleMode = .resizeFill
        scene.snapshot = snapshot
        return scene
    }

    private func tickRender() {
        var sim = Simulation()
        let frames = input.framesForTick()
        sim.step(inputs: frames, snapshot: &snapshot)
    }
}