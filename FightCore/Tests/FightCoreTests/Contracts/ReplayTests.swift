import XCTest
@testable import FightCore

final class ReplayTests: XCTestCase {
    func testEachReplayIsDeterministicPerTick() throws {
        let dir = ContentPaths.replaysDirectory()
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        XCTAssertFalse(files.isEmpty)
        for file in files {
            let fixture = try ReplayRunner.load(from: file)
            let first = ReplayRunner.run(fixture)
            let second = ReplayRunner.run(fixture)
            XCTAssertEqual(first.count, second.count, file.lastPathComponent)
            for (a, b) in zip(first, second) {
                XCTAssertEqual(a, b, file.lastPathComponent)
            }
        }
    }

    func testStateHashChangesWithTick() throws {
        var snap = SimulationBootstrap.greyboxMatch(seed: 1)
        let h0 = snap.stateHash()
        var sim = Simulation()
        sim.step(inputs: [InputFrame(), InputFrame()], snapshot: &snap)
        XCTAssertNotEqual(h0, snap.stateHash())
    }
}