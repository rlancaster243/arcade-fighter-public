import XCTest
@testable import FightCore

/// Roster FightSim reports shipped fighters without changing greybox batch behaviour.
final class RosterMatchTests: XCTestCase {
    func testRosterCommandsMapShippedMotions() throws {
        let ilse = try RosterCommandTable.commands(forFighterIDs: ["ilse"])
        let table = MoveCommandTable(commands: ilse)
        let bead = table.moveID(
            fighterID: "ilse",
            resolved: ResolvedInput(
                motion: .qcf236,
                buttons: MoveCommandTable.bit(.heavyPunch),
                priority: .special
            )
        )
        XCTAssertEqual(bead, "sp_prayer_hp")

        let bruno = try RosterCommandTable.commands(forFighterIDs: ["bruno"])
        let brunoTable = MoveCommandTable(commands: bruno)
        let lift = brunoTable.moveID(
            fighterID: "bruno",
            resolved: ResolvedInput(
                motion: .qcf236,
                buttons: MoveCommandTable.bit(.heavyKick),
                priority: .special
            )
        )
        XCTAssertEqual(lift, "sp_bellows")
        let normalThrow = brunoTable.moveID(
            fighterID: "bruno",
            resolved: ResolvedInput(
                buttons: MoveCommandTable.bit(.lightPunch) | MoveCommandTable.bit(.lightKick)
            )
        )
        XCTAssertEqual(normalThrow, "throw_lp_lk")
    }

    func testRosterMatchIsDeterministicAndSamplesDistance() throws {
        let config = RosterMatchDriver.Config(
            p1FighterID: "kestrel",
            p2FighterID: "bruno",
            stageID: "stage1",
            seedStart: 1,
            seedEnd: 2,
            p1Difficulty: .hard,
            p2Difficulty: .hard,
            tickLimit: 40
        )
        let a = try RosterMatchDriver.run(config)
        let b = try RosterMatchDriver.run(config)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.schemaVersion, 1)
        XCTAssertEqual(a.matches.count, 2)
        XCTAssertEqual(a.p1FighterID, "kestrel")
        XCTAssertEqual(a.p2FighterID, "bruno")
        XCTAssertGreaterThan(a.engagementSamples, 0)
        XCTAssertGreaterThan(a.meanEngagementDistancePx, 0)
        XCTAssertEqual(a.p1Wins + a.p2Wins + a.draws, Int32(a.matches.count))
        for match in a.matches {
            XCTAssertEqual(match.ticksSimulated, 40)
            XCTAssertFalse(match.finalStateHash == 0)
        }
    }

    func testRosterReportRoundTripsJSON() throws {
        let config = RosterMatchDriver.Config(
            p1FighterID: "ilse",
            p2FighterID: "ilse",
            seedStart: 7,
            seedEnd: 7,
            tickLimit: 15
        )
        let report = try RosterMatchDriver.run(config)
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(RosterSimReport.self, from: data)
        XCTAssertEqual(decoded, report)
        XCTAssertEqual(decoded.matches[0].seed, 7)
    }
}