import Foundation

public struct ReplayFixture: Decodable, Sendable {
    public struct TickInput: Decodable, Sendable {
        public let p1: InputCodable
        public let p2: InputCodable
    }

    public struct InputCodable: Decodable, Sendable {
        public let direction: Int8
        public let buttons: UInt8
    }

    public let seed: UInt64
    public let fighters: [String]
    public let inputs: [TickInput]

    public func inputFrames(at index: Int) -> [InputFrame] {
        guard index >= 0, index < inputs.count else {
            return [InputFrame(), InputFrame()]
        }
        let t = inputs[index]
        return [t.p1.frame, t.p2.frame]
    }
}

private extension ReplayFixture.InputCodable {
    var frame: InputFrame {
        InputFrame(direction: Direction(rawValue: direction) ?? .neutral, buttons: buttons)
    }
}

public enum ReplayRunner {
    public static func run(_ fixture: ReplayFixture, maxTicks: Int = 600) -> [UInt64] {
        var sim = Simulation()
        var snap = SimulationBootstrap.greyboxMatch(seed: fixture.seed)
        snap.fighterIDs = fixture.fighters
        var hashes: [UInt64] = []
        hashes.reserveCapacity(min(fixture.inputs.count, maxTicks))
        let limit = min(fixture.inputs.count, maxTicks)
        for i in 0..<limit {
            hashes.append(snap.stateHash())
            let frames = fixture.inputFrames(at: i)
            sim.step(inputs: frames, snapshot: &snap)
        }
        hashes.append(snap.stateHash())
        return hashes
    }

    public static func load(from url: URL) throws -> ReplayFixture {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ReplayFixture.self, from: data)
    }
}