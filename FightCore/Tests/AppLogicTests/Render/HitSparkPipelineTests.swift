import XCTest
import FightCore
@testable import AppLogic

/// End to end through the playable stack: a landed normal must yield a hit-spark request.
final class HitSparkPipelineTests: XCTestCase {
    func testLandedHeavyPunchProducesAHitSpark() throws {
        let kestrel = try FighterLoader.loadFighter(from: ContentPaths.fighterDirectory("kestrel", fromFile: #filePath))
        let bruno = try FighterLoader.loadFighter(from: ContentPaths.fighterDirectory("bruno", fromFile: #filePath))
        var built = try MatchSimulationFactory.make(
            p1PickID: "kestrel", p1: kestrel, p2PickID: "bruno", p2: bruno, stageId: "stage1", fromFile: #filePath
        )
        var snap = MatchSimulationFactory.matchSnapshot(seed: 1, p1: kestrel, p2: bruno, fighterIDs: ["kestrel", "bruno"])
        var kinds: [GameEventKind] = []
        var sparks: [SparkRequest] = []
        // walk in, then a heavy punch
        for tick in 0..<200 {
            var p1 = InputFrame(direction: tick < 60 ? .right : .neutral)
            if tick == 70 { p1.set(.heavyPunch, pressed: true) }
            built.simulation.step(inputs: [p1, InputFrame()], snapshot: &snap)
            kinds += snap.events.map(\.kind)
            sparks += CombatPresentation.sparks(from: snap)
        }
        XCTAssertLessThan(snap.fighters[1].health, bruno.health, "the punch should land; events: \(kinds)")
        XCTAssertFalse(sparks.isEmpty, "a landed hit must request a spark; events seen: \(kinds)")
    }
}

final class SparkLifeTests: XCTestCase {
    func testSparkLivesFourteenTicksAndExpands() {
        let first = SparkLife.state(ageTicks: 0)!
        let last = SparkLife.state(ageTicks: SparkLife.ticks - 1)!
        XCTAssertEqual(first.alpha, 1.0)
        XCTAssertGreaterThan(last.radius, first.radius)
        XCTAssertGreaterThan(last.alpha, 0)
        XCTAssertNil(SparkLife.state(ageTicks: SparkLife.ticks))
        XCTAssertNil(SparkLife.state(ageTicks: -1))
    }
}

final class FXEventInboxTests: XCTestCase {
    private func snap(tick: Int32, _ events: [GameEvent]) -> GameSnapshot {
        var s = SimulationBootstrap.greyboxMatch()
        s.tick = tick
        s.events = events
        return s
    }

    func testEventsSurviveWhenTheRendererMissesTheirSnapshot() {
        var inbox = FXEventInbox()
        inbox.receive(snap(tick: 10, [GameEvent(kind: .hit, tick: 10)]))
        inbox.receive(snap(tick: 11, []))           // renderer only samples this one
        XCTAssertEqual(inbox.drain().map(\.kind), [.hit])
        XCTAssertTrue(inbox.drain().isEmpty)
    }

    func testCumulativeFramePublishesAreNotDoubleCounted() {
        var inbox = FXEventInbox()
        let e1 = GameEvent(kind: .hit, tick: 20), e2 = GameEvent(kind: .block, tick: 21)
        inbox.receive(snap(tick: 20, [e1]))
        inbox.receive(snap(tick: 21, [e1, e2]))
        XCTAssertEqual(inbox.drain().map(\.kind), [.hit, .block])
    }

    func testTickRewindStartsFresh() {
        var inbox = FXEventInbox()
        inbox.receive(snap(tick: 500, [GameEvent(kind: .hit, tick: 500)]))
        _ = inbox.drain()
        inbox.receive(snap(tick: 3, [GameEvent(kind: .hit, tick: 3)]))
        XCTAssertEqual(inbox.drain().count, 1)
    }
}
