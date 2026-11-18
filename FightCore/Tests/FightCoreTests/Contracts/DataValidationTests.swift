import XCTest
@testable import FightCore

final class DataValidationTests: XCTestCase {
    func testGreyboxLoads() throws {
        let dir = ContentPaths.greyboxDirectory()
        let def = try FighterLoader.loadFighter(from: dir)
        XCTAssertEqual(def.schemaVersion, 1)
        XCTAssertEqual(def.id, "greybox")
        XCTAssertEqual(def.moves.count, 7)
        let states = Set(def.hurtboxes.map(\.state))
        XCTAssertEqual(states.count, FighterStateKind.allCases.count)
    }

    func testWrongSchemaVersion() throws {
        let url = badCaseDirectory("bad_schema_version")
        XCTAssertThrowsError(try loadFixture(at: url)) { error in
            XCTAssertEqual(error as? FighterLoadError, .wrongSchemaVersion(2))
        }
    }

    func testDuplicateMoveID() throws {
        let url = badCaseDirectory("bad_duplicate_move")
        XCTAssertThrowsError(try loadFixture(at: url)) { error in
            XCTAssertEqual(error as? FighterLoadError, .duplicateMoveID("norm_lp"))
        }
    }

    func testNegativeFrameCount() throws {
        let url = badCaseDirectory("bad_negative_frames")
        XCTAssertThrowsError(try loadFixture(at: url)) { error in
            if case .negativeFrameCount(let id)? = error as? FighterLoadError {
                XCTAssertEqual(id, "norm_lp")
            } else {
                XCTFail("expected negativeFrameCount")
            }
        }
    }

    func testFrameBoxCountMismatch() throws {
        let url = badCaseDirectory("bad_box_mismatch")
        XCTAssertThrowsError(try loadFixture(at: url)) { error in
            if case .frameBoxCountMismatch(let id)? = error as? FighterLoadError {
                XCTAssertTrue(id.contains("norm_lp"))
            } else {
                XCTFail("expected frameBoxCountMismatch")
            }
        }
    }

    func testMissingSpriteName() throws {
        let url = badCaseDirectory("bad_missing_sprite")
        XCTAssertThrowsError(try loadFixture(at: url)) { error in
            XCTAssertEqual(error as? FighterLoadError, .missingSpriteName("missing_frame"))
        }
    }

    func testUnblockableNonThrow() throws {
        let url = badCaseDirectory("bad_unblockable")
        XCTAssertThrowsError(try loadFixture(at: url)) { error in
            XCTAssertEqual(error as? FighterLoadError, .unblockableNonThrow("cheat"))
        }
    }

    func testEmptyGamePlan() throws {
        let url = badCaseDirectory("bad_empty_gameplan")
        XCTAssertThrowsError(try loadFixture(at: url)) { error in
            XCTAssertEqual(error as? FighterLoadError, .emptyGamePlan)
        }
    }

    func testNegativeWalkSpeedRejected() throws {
        try assertLoad("\"walkForward\": -1", equals: .negativeWalkSpeed)
    }

    func testNegativeArmorHitsRejected() throws {
        try assertLoad("\"armorHits\": -1", equals: .negativeArmorHits("only"))
    }

    func testProjectileLifetimeRejected() throws {
        try assertLoad(projectile(lifetime: 0), equals: .invalidProjectileLifetime("only"))
    }

    func testProjectileSpawnCountRejected() throws {
        try assertLoad(projectile(spawnCount: 0), equals: .invalidProjectileSpawnCount("only"))
    }

    func testProjectileSpawnCountAboveActiveRejected() throws {
        try assertLoad(projectile(spawnCount: 4), equals: .invalidProjectileSpawnCount("only"))
    }

    func testProjectileMaxOnScreenRejected() throws {
        try assertLoad(projectile(maxOnScreen: 0), equals: .invalidProjectileMaxOnScreen("only"))
    }

    func testProjectileDamageRejected() throws {
        try assertLoad(projectile(damage: -1), equals: .invalidProjectileDamage("only"))
    }

    func testProjectileHitboxRejected() throws {
        try assertLoad(projectile(hitW: 0), equals: .invalidProjectileHitbox("only"))
    }

    func testVelocityFrameCountRejected() throws {
        try assertLoad("\"velocities\": [{\"x\": 256, \"y\": 0}]", equals: .velocityFrameCount("only"))
    }

    func testInvulnerableFrameRejected() throws {
        try assertLoad("\"invulnerableFrames\": [9]", equals: .invalidInvulnerableFrame("only"))
    }

    func testWhiffsVsAirborneNonThrowRejected() throws {
        try assertLoad("\"whiffsVsAirborne\": true", equals: .whiffsVsAirborneNonThrow("only"))
    }

    func testCounterWindowRejected() throws {
        let extra = """
        "counter": { "startTick": 1, "endTick": 1, "followUpMoveID": "follow" }
        """
        try assertLoad(extra, equals: .invalidCounterWindow("only"))
    }

    func testMissingCounterFollowUpRejected() throws {
        let extra = """
        "counter": { "startTick": 0, "endTick": 1, "followUpMoveID": "nope" }
        """
        try assertLoad(extra, equals: .missingCounterFollowUp("only"))
    }

    func testMultiHitFrameRejected() throws {
        let extra = """
        "hits": [{ "activeFrame": 3, "damage": 10, "hitstun": 4, "blockstun": 4, "hitstop": 6 }]
        """
        try assertLoad(extra, equals: .invalidMultiHit("only"))
    }

    private func badCaseDirectory(_ name: String) -> URL {
        ContentPaths.badFighterCaseDirectory(name)
    }

    private func loadFixture(at dir: URL) throws -> FighterDef {
        try FighterLoader.loadFighter(from: dir)
    }

    private func assertLoad(_ extraMoveJSON: String, equals expected: FighterLoadError) throws {
        let json = Self.fighterJSON(extraMoveFields: extraMoveJSON)
        XCTAssertThrowsError(try loadJSON(json)) { error in
            XCTAssertEqual(error as? FighterLoadError, expected)
        }
    }

    private func loadJSON(_ json: String) throws -> FighterDef {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fix-a-bad-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try json.write(to: dir.appendingPathComponent("fighter.json"), atomically: true, encoding: .utf8)
        try "[]".write(to: dir.appendingPathComponent("sheet.json"), atomically: true, encoding: .utf8)
        try Data().write(to: dir.appendingPathComponent("s.png"))
        return try FighterLoader.loadFighter(from: dir)
    }

    private func projectile(
        lifetime: Int = 10,
        spawnCount: Int = 1,
        maxOnScreen: Int = 1,
        damage: Int = 5,
        hitW: Int = 8
    ) -> String {
        """
        "projectile": {
          "speed": 256, "lifetime": \(lifetime), "damage": \(damage),
          "maxOnScreen": \(maxOnScreen), "spawnCount": \(spawnCount), "hitsAirborne": false,
          "hitbox": { "x": 0, "y": -20, "w": \(hitW), "h": 8 }
        }
        """
    }

    private static func fighterJSON(extraMoveFields: String) -> String {
        let box = "{ \"x\": -10, \"y\": -40, \"w\": 20, \"h\": 40 }"
        let walk = extraMoveFields.contains("walkForward") ? extraMoveFields : "\"walkForward\": 256"
        let moveExtra = extraMoveFields.contains("walkForward") ? "" : extraMoveFields
        let moveTail = moveExtra.isEmpty ? "" : ",\n        \(moveExtra)"
        return """
        {
          "schemaVersion": 1,
          "id": "bad",
          "displayName": "Bad",
          "archetype": "test",
          "gamePlan": "rejection fixture",
          "health": 1000,
          \(walk),
          "walkBack": 256,
          "jump": { "velocityY": -3584, "gravity": 256 },
          "pushbox": { "x": -20, "y": -90, "w": 40, "h": 90 },
          "hurtboxes": [{ "state": "idle", "boxes": [\(box)] }],
          "spriteSheet": "s.png",
          "sheetMeta": "sheet.json",
          "moves": [{
            "id": "only",
            "name": "Only",
            "input": { "button": "LP", "stance": "stand" },
            "startup": 1,
            "active": 1,
            "recovery": 1,
            "frames": {
              "hit": [\(box)],
              "hurt": [\(box)],
              "push": [\(box)],
              "throw": []
            },
            "damage": 10,
            "chip": 0,
            "hitstun": 4,
            "blockstun": 4,
            "pushbackHit": 1,
            "pushbackBlock": 1,
            "meterGain": 10,
            "hitstop": 6,
            "guard": "mid",
            "unblockable": false\(moveTail)
          }, {
            "id": "follow",
            "name": "Follow",
            "input": { "button": "HP", "stance": "stand" },
            "startup": 1,
            "active": 1,
            "recovery": 1,
            "frames": {
              "hit": [\(box)],
              "hurt": [\(box)],
              "push": [\(box)],
              "throw": []
            },
            "damage": 10,
            "chip": 0,
            "hitstun": 4,
            "blockstun": 4,
            "pushbackHit": 1,
            "pushbackBlock": 1,
            "meterGain": 10,
            "hitstop": 6,
            "guard": "mid",
            "unblockable": false
          }]
        }
        """
    }
}