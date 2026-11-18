import XCTest
@testable import FightCore

final class MoveCommandTableTests: XCTestCase {
    func testForwardWalkAppliesWalkSpeedSameTick() {
        let def = FighterDef(id: "greybox", displayName: "G", gamePlan: "t", walkForward: 256)
        var sim = Simulation(
            motion: MotionParser(),
            fighterStep: FighterStepper(definitions: ["greybox": def])
        )
        var snap = SimulationBootstrap.greyboxMatch()
        let start = snap.fighters[0].position.x.raw
        sim.step(inputs: [InputFrame(direction: .right), InputFrame()], snapshot: &snap)
        XCTAssertEqual(snap.fighters[0].kind, .walkForward)
        XCTAssertEqual(snap.fighters[0].position.x.raw - start, 256)
    }

    func testQuarterCircleForwardStartsTheBoundMove() {
        let move = MoveDef(id: "sp_qcf", name: "QCF", inputKind: .special, startup: 2, active: 2, recovery: 2)
        let def = FighterDef(id: "greybox", displayName: "G", gamePlan: "t", moves: [move])
        let table = MoveCommandTable(commands: [
            MoveCommand(
                fighterID: "greybox",
                moveID: "sp_qcf",
                motion: .qcf236,
                buttons: 1 << Button.lightPunch.rawValue
            ),
        ])
        var sim = Simulation(
            motion: MotionParser(commands: table),
            fighterStep: FighterStepper(definitions: ["greybox": def])
        )
        var snap = SimulationBootstrap.greyboxMatch()
        let dirs: [Direction] = [.down, .downRight, .right]
        for (index, dir) in dirs.enumerated() {
            var frame = InputFrame(direction: dir)
            if index == dirs.count - 1 {
                frame.set(.lightPunch, pressed: true)
            }
            sim.step(inputs: [frame, InputFrame()], snapshot: &snap)
        }
        XCTAssertEqual(snap.fighters[0].activeMoveID, "sp_qcf")
        XCTAssertEqual(snap.fighters[0].kind, .attackStartup)
    }

    func testLightPunchDoesNotThrowAndLightPunchPlusLightKickDoes() {
        let jab = MoveDef(id: "norm_lp", name: "LP", inputKind: .normal, startup: 1, active: 1, recovery: 1)
        let toss = MoveDef(id: "throw_lp_lk", name: "Throw", inputKind: .throwMove, startup: 1, active: 1, recovery: 1)
        let def = FighterDef(id: "greybox", displayName: "G", gamePlan: "t", moves: [jab, toss])
        let lp = UInt8(1 << Button.lightPunch.rawValue)
        let lk = UInt8(1 << Button.lightKick.rawValue)
        let table = MoveCommandTable(commands: [
            MoveCommand(fighterID: "greybox", moveID: "norm_lp", motion: nil, buttons: lp),
            MoveCommand(fighterID: "greybox", moveID: "throw_lp_lk", motion: nil, buttons: lp | lk),
        ])
        var jabSim = Simulation(
            motion: MotionParser(commands: table),
            fighterStep: FighterStepper(definitions: ["greybox": def])
        )
        var jabSnap = SimulationBootstrap.greyboxMatch()
        var lpFrame = InputFrame()
        lpFrame.set(.lightPunch, pressed: true)
        jabSim.step(inputs: [lpFrame, InputFrame()], snapshot: &jabSnap)
        XCTAssertEqual(jabSnap.fighters[0].activeMoveID, "norm_lp")

        var throwSim = Simulation(
            motion: MotionParser(commands: table),
            fighterStep: FighterStepper(definitions: ["greybox": def])
        )
        var throwSnap = SimulationBootstrap.greyboxMatch()
        var throwFrame = InputFrame()
        throwFrame.set(.lightPunch, pressed: true)
        throwFrame.set(.lightKick, pressed: true)
        throwSim.step(inputs: [throwFrame, InputFrame()], snapshot: &throwSnap)
        XCTAssertEqual(throwSnap.fighters[0].activeMoveID, "throw_lp_lk")
    }

    func testPunchClassBindsBothPunchButtonsToOneMove() {
        let quake = MoveDef(id: "sp_forge", name: "Forge Quake", inputKind: .special, startup: 1, active: 1, recovery: 1)
        let def = FighterDef(id: "bruno", displayName: "B", gamePlan: "t", moves: [quake])
        let table = MoveCommandTable(commands: [
            MoveCommand(fighterID: "bruno", moveID: "sp_forge", motion: .qcb214, buttons: 1 << Button.lightPunch.rawValue),
            MoveCommand(fighterID: "bruno", moveID: "sp_forge", motion: .qcb214, buttons: 1 << Button.heavyPunch.rawValue),
        ])
        for button in [Button.lightPunch, Button.heavyPunch] {
            var sim = Simulation(
                motion: MotionParser(commands: table),
                fighterStep: FighterStepper(definitions: ["bruno": def])
            )
            var snap = SimulationBootstrap.greyboxMatch()
            snap.fighterIDs = ["bruno", "greybox"]
            let dirs: [Direction] = [.down, .downLeft, .left]
            for (index, dir) in dirs.enumerated() {
                var frame = InputFrame(direction: dir)
                if index == dirs.count - 1 {
                    frame.set(button, pressed: true)
                }
                sim.step(inputs: [frame, InputFrame()], snapshot: &snap)
            }
            XCTAssertEqual(snap.fighters[0].activeMoveID, "sp_forge", "\(button) should start Forge Quake")
        }
    }
}
