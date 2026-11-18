import XCTest
@testable import FightCore

final class DeterminismTests: XCTestCase {
    func testSimulationStubCompilesAndSteps() {
        var sim = Simulation()
        var snap = SimulationBootstrap.greyboxMatch(seed: 99)
        sim.step(inputs: [InputFrame(), InputFrame()], snapshot: &snap)
        XCTAssertEqual(snap.fighters.count, 2)
    }

    func testSeededRNGIsDeterministic() {
        var a = SeededRNG(seed: 123)
        var b = SeededRNG(seed: 123)
        for _ in 0..<10 {
            XCTAssertEqual(a.next(), b.next())
        }
    }
}