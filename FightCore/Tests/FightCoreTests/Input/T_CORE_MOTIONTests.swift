import XCTest
@testable import FightCore

/// T-CORE-MOTION: leniency, DP shortcut, facing flip, motion priority.
final class T_CORE_MOTIONTests: XCTestCase {
    private let pattern236: [UInt8] = [2, 3, 6]
    private let pattern214: [UInt8] = [2, 1, 4]
    private let pattern623: [UInt8] = [6, 2, 3]
    private let pattern6323: [UInt8] = [6, 3, 2, 3]
    private let patternSuper: [UInt8] = [2, 3, 6, 2, 3, 6]

    private func buffer(facingRight: Bool, pads spread: [UInt8]) -> InputRingBuffer {
        var parser = MotionParser()
        for (i, pad) in spread.enumerated() {
            let dir = direction(forNumpad: pad)
            let buttons: UInt8 = (i == spread.count - 1) ? (1 << Button.lightPunch.rawValue) : 0
            _ = parser.push(slot: .p1, direction: dir, buttons: buttons, facingRight: facingRight)
        }
        return parser.tracker(for: .p1).buffer
    }

    private func direction(forNumpad n: UInt8) -> Direction {
        switch n {
        case 0: .neutral
        case 1: .downLeft
        case 2: .down
        case 3: .downRight
        case 4: .left
        case 6: .right
        case 7: .upLeft
        case 8: .up
        case 9: .upRight
        default: .neutral
        }
    }

    func test236AcceptedWithinSpecialLeniency() {
        for gap in 0 ... 8 {
            var ring = InputRingBuffer()
            ring.push(numpad: 2, buttons: 0)
            for _ in 0 ..< gap { ring.push(numpad: 0, buttons: 0) }
            ring.push(numpad: 3, buttons: 0)
            for _ in 0 ..< gap { ring.push(numpad: 0, buttons: 0) }
            ring.push(numpad: 6, buttons: 1)
            XCTAssertTrue(MotionMatcher.spanMatches(pattern: pattern236, maxSpan: 11, buffer: ring))
        }
        var p = MotionParser()
        for pad in pattern236 {
            _ = p.push(slot: .p1, direction: direction(forNumpad: pad), buttons: 0, facingRight: true)
        }
        _ = p.push(
            slot: .p1,
            direction: .right,
            buttons: 1 << Button.lightPunch.rawValue,
            facingRight: true
        )
        XCTAssertEqual(p.resolvedInput(for: .p1).motion, .qcf236)
    }

    func test236RejectedAtTwelveTicks() {
        var p = MotionParser()
        _ = p.push(slot: .p1, direction: .down, buttons: 0, facingRight: true)
        for _ in 0 ..< 10 { _ = p.push(slot: .p1, direction: .neutral, buttons: 0, facingRight: true) }
        _ = p.push(slot: .p1, direction: .downRight, buttons: 0, facingRight: true)
        for _ in 0 ..< 10 { _ = p.push(slot: .p1, direction: .neutral, buttons: 0, facingRight: true) }
        _ = p.push(
            slot: .p1,
            direction: .right,
            buttons: 1 << Button.lightPunch.rawValue,
            facingRight: true
        )
        let buf = p.tracker(for: .p1).buffer
        XCTAssertGreaterThan(MotionMatcher.matchingSpan(pattern: pattern236, buffer: buf) ?? 0, 11)
        XCTAssertNil(p.resolvedInput(for: .p1).motion)
    }

    func test214Qcb() {
        var p = MotionParser()
        for pad in pattern214 {
            _ = p.push(slot: .p1, direction: direction(forNumpad: pad), buttons: 0, facingRight: true)
        }
        _ = p.push(
            slot: .p1,
            direction: .left,
            buttons: 1 << Button.heavyPunch.rawValue,
            facingRight: true
        )
        XCTAssertEqual(p.resolvedInput(for: .p1).motion, .qcb214)
    }

    func test623AndDPShortcut6323() {
        var p = MotionParser()
        for pad in pattern623 {
            _ = p.push(slot: .p1, direction: direction(forNumpad: pad), buttons: 0, facingRight: true)
        }
        _ = p.push(
            slot: .p1,
            direction: .downRight,
            buttons: 1 << Button.lightKick.rawValue,
            facingRight: true
        )
        XCTAssertEqual(p.resolvedInput(for: .p1).motion, .dp623)

        p = MotionParser()
        for pad in pattern6323 {
            _ = p.push(slot: .p1, direction: direction(forNumpad: pad), buttons: 0, facingRight: true)
        }
        _ = p.push(
            slot: .p1,
            direction: .downRight,
            buttons: 1 << Button.lightKick.rawValue,
            facingRight: true
        )
        XCTAssertEqual(p.resolvedInput(for: .p1).motion, .dp623)
    }

    func testSuper236236Leniency() {
        var p = MotionParser()
        for pad in patternSuper {
            _ = p.push(slot: .p1, direction: direction(forNumpad: pad), buttons: 0, facingRight: true)
        }
        _ = p.push(
            slot: .p1,
            direction: .right,
            buttons: 1 << Button.heavyKick.rawValue,
            facingRight: true
        )
        XCTAssertEqual(p.resolvedInput(for: .p1).motion, .super236236)

        p = MotionParser()
        _ = p.push(slot: .p1, direction: .down, buttons: 0, facingRight: true)
        for _ in 0 ..< 18 {
            _ = p.push(slot: .p1, direction: .neutral, buttons: 0, facingRight: true)
        }
        for pad in patternSuper.dropFirst() {
            _ = p.push(slot: .p1, direction: direction(forNumpad: pad), buttons: 0, facingRight: true)
        }
        _ = p.push(
            slot: .p1,
            direction: .right,
            buttons: 1 << Button.heavyKick.rawValue,
            facingRight: true
        )
        XCTAssertNil(p.resolvedInput(for: .p1).motion)
    }

    func testFacingFlipMidMotion() {
        var p = MotionParser()
        _ = p.push(slot: .p1, direction: .down, buttons: 0, facingRight: true)
        _ = p.push(slot: .p1, direction: .downRight, buttons: 0, facingRight: true)
        _ = p.push(slot: .p1, direction: .left, buttons: 0, facingRight: false)
        _ = p.push(
            slot: .p1,
            direction: .left,
            buttons: 1 << Button.lightPunch.rawValue,
            facingRight: false
        )
        XCTAssertEqual(p.resolvedInput(for: .p1).motion, .qcf236)
    }

    func testSuperWinsPriorityOverSpecial() {
        var p = MotionParser()
        for pad in patternSuper {
            _ = p.push(slot: .p1, direction: direction(forNumpad: pad), buttons: 0, facingRight: true)
        }
        _ = p.push(
            slot: .p1,
            direction: .right,
            buttons: 1 << Button.lightPunch.rawValue,
            facingRight: true
        )
        let r = p.resolvedInput(for: .p1)
        XCTAssertEqual(r.motion, .super236236)
        XCTAssertEqual(r.priority, .superMove)
    }

    func testSpanBoundaries() {
        XCTAssertTrue(MotionMatcher.spanMatches(pattern: pattern236, maxSpan: 11, buffer: buffer(facingRight: true, pads: [2, 3, 6])))
        var wide = InputRingBuffer()
        wide.push(numpad: 2, buttons: 0)
        for _ in 0 ..< 11 { wide.push(numpad: 0, buttons: 0) }
        wide.push(numpad: 3, buttons: 0)
        wide.push(numpad: 6, buttons: 1)
        XCTAssertFalse(MotionMatcher.spanMatches(pattern: pattern236, maxSpan: 11, buffer: wide))
    }
}