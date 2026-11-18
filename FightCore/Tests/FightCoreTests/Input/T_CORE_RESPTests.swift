import XCTest
@testable import FightCore

/// T-CORE-RESP (input): ring depth, same-tick visibility, apply path integration.
final class T_CORE_RESPTests: XCTestCase {
    func testRingCapacity32() {
        var ring = InputRingBuffer()
        for i in 1 ... 40 {
            ring.push(numpad: UInt8(i % 10), buttons: 0)
        }
        XCTAssertEqual(ring.frameCount, InputRingBuffer.capacity)
        XCTAssertEqual(ring.entry(ago: 0)?.numpad, 0)
        XCTAssertEqual(ring.entry(ago: 31)?.numpad, 9)
        XCTAssertNil(ring.entry(ago: 32))
    }

    func testInputVisibleSameTick() {
        var parser = MotionParser()
        let resolved = parser.push(
            slot: .p1,
            direction: .down,
            buttons: 1 << Button.lightPunch.rawValue,
            facingRight: true
        )
        XCTAssertEqual(resolved.buttons, 1 << Button.lightPunch.rawValue)
        XCTAssertEqual(resolved.priority, .normal)
        XCTAssertEqual(parser.tracker(for: .p1).buffer.entry(ago: 0)?.numpad, 2)
    }

    func testSimulationMotionStep() {
        var sim = Simulation(motion: MotionParser())
        var snap = SimulationBootstrap.greyboxMatch()
        let pads: [Direction] = [.down, .downRight, .right]
        for (i, dir) in pads.enumerated() {
            let buttons: UInt8 = (i == pads.count - 1) ? (1 << Button.lightPunch.rawValue) : 0
            sim.step(inputs: [InputFrame(direction: dir, buttons: buttons), InputFrame()], snapshot: &snap)
        }
        guard var parsed = sim.motion as? MotionParser else {
            XCTFail("expected MotionParser")
            return
        }
        XCTAssertEqual(parsed.resolvedInput(for: .p1).motion, .qcf236)
        _ = parsed
    }

    func testFacingMirrorRoundTrip() {
        XCTAssertEqual(FacingInput.mirrorNumpad(FacingInput.mirrorNumpad(6)), 6)
        XCTAssertEqual(FacingInput.logicalNumpad(from: .right, facingRight: false), 4)
        XCTAssertEqual(FacingInput.logicalNumpad(from: .left, facingRight: false), 6)
    }
}