import XCTest
@testable import FightCore

final class ContentPathsBundleTests: XCTestCase {
    private var resources: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        resources = FileManager.default.temporaryDirectory
            .appendingPathComponent("ContentPathsBundleTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let resources {
            try? FileManager.default.removeItem(at: resources)
        }
        resources = nil
        try super.tearDownWithError()
    }

    func testFighterAndStageDirectoriesPreferBundleWhenGreyboxMarkerExists() throws {
        let marker = resources
            .appendingPathComponent("Content/Fighters/greybox/greybox.contentbundle", isDirectory: true)
            .appendingPathComponent("fighter.json")
        try FileManager.default.createDirectory(
            at: marker.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("{}".utf8).write(to: marker)

        let fighter = ContentPaths.fighterDirectory("kestrel", resourcesURL: resources)
        let stage = ContentPaths.stageDirectory("stage1", resourcesURL: resources)
        let sourceFighter = ContentPaths.fighterDirectory("kestrel", fromFile: #filePath)

        XCTAssertEqual(
            normalized(fighter),
            normalized(resources.appendingPathComponent(
                "Content/Fighters/kestrel/kestrel.contentbundle",
                isDirectory: true
            ))
        )
        XCTAssertEqual(
            normalized(stage),
            normalized(resources.appendingPathComponent(
                "Content/Stages/stage1/stage1.contentbundle",
                isDirectory: true
            ))
        )
        XCTAssertNotEqual(normalized(fighter), normalized(sourceFighter))

        let forcedSource = ContentPaths.fighterDirectory(
            "kestrel",
            fromFile: #filePath,
            repoRoot: ContentPaths.repoRoot(fromFile: #filePath),
            resourcesURL: resources
        )
        XCTAssertEqual(normalized(forcedSource), normalized(sourceFighter))
    }

    func testFighterAndStageDirectoriesFallBackToSourceTreeWhenMarkerIsAbsent() throws {
        let fighter = ContentPaths.fighterDirectory("kestrel", fromFile: #filePath, resourcesURL: resources)
        let stage = ContentPaths.stageDirectory("stage1", fromFile: #filePath, resourcesURL: resources)
        let sourceFighter = ContentPaths.fighterDirectory("kestrel", fromFile: #filePath)
        let sourceStage = ContentPaths.stageDirectory("stage1", fromFile: #filePath)

        XCTAssertFalse(FileManager.default.fileExists(
            atPath: resources
                .appendingPathComponent("Content/Fighters/greybox/greybox.contentbundle/fighter.json")
                .path
        ))
        XCTAssertEqual(normalized(fighter), normalized(sourceFighter))
        XCTAssertEqual(normalized(stage), normalized(sourceStage))
        XCTAssertTrue(fighter.path.contains("Content/Fighters/kestrel/kestrel.contentbundle"))
        XCTAssertTrue(stage.path.contains("Content/Stages/stage1/stage1.contentbundle"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fighter.appendingPathComponent("fighter.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: stage.appendingPathComponent("stage.json").path))
    }

    private func normalized(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
