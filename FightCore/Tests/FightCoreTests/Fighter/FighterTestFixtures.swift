import Foundation
@testable import FightCore

enum FighterTestFixtures {
    static func greyboxDef() throws -> FighterDef {
        try FighterLoader.loadFighter(from: ContentPaths.greyboxDirectory())
    }

    static func baseSnapshot(def: FighterDef) -> GameSnapshot {
        var snap = SimulationBootstrap.greyboxMatch(seed: 1)
        snap.fighterIDs = [def.id, def.id]
        snap.fighters[0].position = Vec2(x: Fixed(pixels: -20), y: .zero)
        snap.fighters[1].position = Vec2(x: Fixed(pixels: 20), y: .zero)
        return snap
    }

    static func stepper(with def: FighterDef) -> FighterStepper {
        var stepper = FighterStepper()
        stepper.registerDefinition(def)
        return stepper
    }

    static func move(_ id: String, in def: FighterDef) -> MoveDef {
        guard let move = def.moves.first(where: { $0.id == id }) else {
            fatalError("missing move \(id)")
        }
        return move
    }
}