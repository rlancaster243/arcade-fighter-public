import XCTest
import FightCore

final class ShippedContentIntegrationTests: XCTestCase {
    private var catalog: ExpectedHashesCatalog!

    override func setUpWithError() throws {
        catalog = try ExpectedHashesCatalog.load()
        XCTAssertEqual(catalog.schemaVersion, 1)
    }

    func testShippedFightersLoad() throws {
        for id in IntegrationMatchHarness.shippedFighterIDs {
            let def = try IntegrationMatchHarness.loadFighter(id)
            XCTAssertEqual(def.id, id)
            XCTAssertFalse(def.moves.isEmpty)
        }
    }

    func testShippedStagesLoad() throws {
        for id in IntegrationMatchHarness.shippedStageIDs {
            let json = try IntegrationMatchHarness.loadStageJSON(id)
            XCTAssertEqual(json["id"] as? String, id)
            XCTAssertEqual(json["schemaVersion"] as? Int, 1)
        }
    }

    func testReplayGreyboxIdleHashes() throws {
        let greybox = try IntegrationMatchHarness.loadFighter("greybox")
        let replayURL = ContentPaths.replaysDirectory().appendingPathComponent("greybox-idle.json")
        let fixture = try ReplayRunner.load(from: replayURL)
        let hashes = IntegrationMatchHarness.runReplay(fixture, p1: greybox, p2: greybox)
        guard let expected = catalog.scenario(id: "replay-greybox-idle") else {
            XCTFail("missing scenario replay-greybox-idle")
            return
        }
        XCTAssertEqual(hashes.last, expected.finalHash, hashDiag(actual: hashes.last, expected: expected.finalHash, scenario: expected.id))
        if let ticks = expected.tickHashes {
            XCTAssertEqual(hashes, ticks)
        }
    }

    func testReplayGreyboxShortHashes() throws {
        let greybox = try IntegrationMatchHarness.loadFighter("greybox")
        let replayURL = ContentPaths.replaysDirectory().appendingPathComponent("greybox-short.json")
        let fixture = try ReplayRunner.load(from: replayURL)
        let hashes = IntegrationMatchHarness.runReplay(fixture, p1: greybox, p2: greybox)
        guard let expected = catalog.scenario(id: "replay-greybox-short") else {
            XCTFail("missing scenario replay-greybox-short")
            return
        }
        XCTAssertEqual(hashes.last, expected.finalHash, hashDiag(actual: hashes.last, expected: expected.finalHash, scenario: expected.id))
        if let ticks = expected.tickHashes {
            XCTAssertEqual(hashes, ticks)
        }
    }

    func testKestrelVsBrunoScriptedSteps() throws {
        let p1 = try IntegrationMatchHarness.loadFighter("kestrel")
        let p2 = try IntegrationMatchHarness.loadFighter("bruno")
        var sim = IntegrationMatchHarness.simulation(p1: p1, p2: p2)
        var snap = IntegrationMatchHarness.snapshot(seed: 0x4B65_7374_4272_756E, p1: p1, p2: p2)
        let frames: [[InputFrame]] = [
            [.p1Forward, .neutral],
            [.p1LP, .neutral],
            [.neutral, .p2BackBlock],
            [.p1HP, .p2LK],
            [.neutral, .neutral],
        ]
        var hashes: [UInt64] = []
        for tick in frames {
            hashes.append(snap.stateHash())
            IntegrationMatchHarness.step(simulation: &sim, snapshot: &snap, inputs: tick)
        }
        hashes.append(snap.stateHash())
        guard let expected = catalog.scenario(id: "script-kestrel-bruno-5t") else {
            XCTFail("missing scenario script-kestrel-bruno-5t")
            return
        }
        XCTAssertEqual(hashes.last, expected.finalHash, hashDiag(actual: hashes.last, expected: expected.finalHash, scenario: expected.id))
        if let ticks = expected.tickHashes {
            XCTAssertEqual(hashes, ticks)
        }
    }

    func testCPUGreyboxHarnessMatch() throws {
        let greybox = try IntegrationMatchHarness.loadFighter("greybox")
        let (_, ticks, hash) = IntegrationMatchHarness.runCPUVsCPU(
            matchSeed: 0xA17C_0001,
            p1: greybox,
            p2: greybox,
            p1Difficulty: .normal,
            p2Difficulty: .hard,
            tickLimit: 180
        )
        XCTAssertEqual(ticks, 180)
        guard let expected = catalog.scenario(id: "cpu-greybox-normal-hard-180t") else {
            XCTFail("missing scenario cpu-greybox-normal-hard-180t")
            return
        }
        XCTAssertEqual(hash, expected.finalHash, hashDiag(actual: hash, expected: expected.finalHash, scenario: expected.id))
    }

    func testCPUIlseVsRookMatch() throws {
        let p1 = try IntegrationMatchHarness.loadFighter("ilse")
        let p2 = try IntegrationMatchHarness.loadFighter("rook")
        let (_, ticks, hash) = IntegrationMatchHarness.runCPUVsCPU(
            matchSeed: 0x110E_1200,
            p1: p1,
            p2: p2,
            p1Difficulty: .easy,
            p2Difficulty: .normal,
            tickLimit: 240
        )
        XCTAssertEqual(ticks, 240)
        guard let expected = catalog.scenario(id: "cpu-ilse-rook-easy-normal-240t") else {
            XCTFail("missing scenario cpu-ilse-rook-easy-normal-240t")
            return
        }
        XCTAssertEqual(hash, expected.finalHash, hashDiag(actual: hash, expected: expected.finalHash, scenario: expected.id))
    }
}

private func hashDiag(actual: UInt64?, expected: UInt64, scenario: String) -> String {
    let a = actual.map { "0x\(String($0, radix: 16))" } ?? "nil"
    let e = "0x\(String(expected, radix: 16))"
    return "\(scenario): actual=\(a) expected=\(e)"
}

private extension InputFrame {
    static let neutral = InputFrame()
    static let p1Forward = InputFrame(direction: .right, buttons: 0)
    static let p1LP = InputFrame(direction: .neutral, buttons: 1 << Button.lightPunch.rawValue)
    static let p1HP = InputFrame(direction: .neutral, buttons: 1 << Button.heavyPunch.rawValue)
    static let p2BackBlock = InputFrame(direction: .left, buttons: 0)
    static let p2LK = InputFrame(direction: .neutral, buttons: 1 << Button.lightKick.rawValue)
}