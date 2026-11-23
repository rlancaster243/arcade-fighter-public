import Foundation

public enum FighterLoader {
    public static func loadFighter(from directory: URL) throws -> FighterDef {
        let fighterURL = directory.appendingPathComponent("fighter.json")
        let data = try Data(contentsOf: fighterURL)
        let decoder = JSONDecoder()
        let fighter: FighterJSON
        do {
            fighter = try decoder.decode(FighterJSON.self, from: data)
        } catch {
            throw FighterLoadError.decodeFailed(String(describing: error))
        }

        let sheetURL = directory.appendingPathComponent(fighter.sheetMeta)
        guard FileManager.default.fileExists(atPath: sheetURL.path) else {
            throw FighterLoadError.missingSheetFile
        }
        let sheetData = try Data(contentsOf: sheetURL)
        let sheet: [SheetFrameJSON]
        do {
            // Bare array (1x sheets) or {"texelScale": N, "frames": [...]} (2x PS2-era sheets).
            if SheetJSONShape.isBareArray(sheetData) {
                sheet = try decoder.decode([SheetFrameJSON].self, from: sheetData)
            } else {
                sheet = try decoder.decode(ScaledSheetJSON.self, from: sheetData).frames
            }
        } catch {
            throw FighterLoadError.decodeFailed("sheet: \(error)")
        }

        try validateSpriteNames(in: fighter, sheet: sheet)
        return try FighterValidator.validate(fighter: fighter, sheet: sheet, fighterDirectory: directory)
    }

    private static func validateSpriteNames(in fighter: FighterJSON, sheet: [SheetFrameJSON]) throws {
        let names = Set(sheet.map(\.name))
        for move in fighter.moves {
            if let sprite = move.sprite, !sprite.isEmpty, !names.contains(sprite) {
                throw FighterLoadError.missingSpriteName(sprite)
            }
        }
    }
}

public enum ContentPaths {
    /// Walks upward from `file` until greybox’s content bundle exists under the candidate root.
    public static func repoRoot(fromFile file: String = #filePath) -> URL {
        var url = URL(fileURLWithPath: file).deletingLastPathComponent()
        let fm = FileManager.default
        for _ in 0..<10 {
            let greybox = fighterDirectory("greybox", fromFile: file, repoRoot: url)
            if fm.fileExists(atPath: greybox.appendingPathComponent("fighter.json").path) {
                return url
            }
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return fallbackRepoRoot(fromFile: file)
    }

  private static func fallbackRepoRoot(fromFile file: String) -> URL {
    var url = URL(fileURLWithPath: file).deletingLastPathComponent()
    for _ in 0..<10 {
      if fmContainsPackageSwift(at: url) {
        return url.deletingLastPathComponent()
      }
      let parent = url.deletingLastPathComponent()
      if parent.path == url.path { break }
      url = parent
    }
    var direct = URL(fileURLWithPath: file)
    for _ in 0..<5 { direct.deleteLastPathComponent() }
    return direct
  }

  private static func fmContainsPackageSwift(at url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path)
  }

    public static func fighterDirectory(
        _ id: String,
        fromFile file: String = #filePath,
        repoRoot root: URL? = nil,
        resourcesURL: URL? = nil
    ) -> URL {
        if root == nil, let bundled = bundledContentRoot(resourcesURL: resourcesURL) {
            return bundled.appendingPathComponent(
                "Fighters/\(id)/\(id).contentbundle",
                isDirectory: true
            )
        }
        let root = root ?? repoRoot(fromFile: file)
        return root
            .appendingPathComponent("Content/Fighters/\(id)/\(id).contentbundle", isDirectory: true)
    }

    public static func stageDirectory(
        _ id: String,
        fromFile file: String = #filePath,
        resourcesURL: URL? = nil
    ) -> URL {
        contentRoot(fromFile: file, resourcesURL: resourcesURL)
            .appendingPathComponent(
                "Stages/\(id)/\(id).contentbundle",
                isDirectory: true
            )
    }

    /// `Content/Audio` inside the app bundle when it ships content, otherwise the checkout.
    public static func audioDirectory(
        fromFile file: String = #filePath,
        resourcesURL: URL? = nil
    ) -> URL {
        contentRoot(fromFile: file, resourcesURL: resourcesURL)
            .appendingPathComponent("Audio", isDirectory: true)
    }

    private static func contentRoot(fromFile file: String, resourcesURL: URL?) -> URL {
        bundledContentRoot(resourcesURL: resourcesURL)
            ?? repoRoot(fromFile: file).appendingPathComponent("Content", isDirectory: true)
    }

    /// Resources/Content when the bundle ships a `Content/Fighters` directory (the app does; a test
    /// runner's bundle does not). `resourcesURL` nil uses `Bundle.main`. An explicit `repoRoot`
    /// still walks the source tree. The marker is structural on purpose: it used to be greybox's
    /// fighter.json, so one broken fighter sent every path to the sandbox-unreadable checkout.
    private static func bundledContentRoot(resourcesURL: URL? = nil) -> URL? {
        guard let resources = resourcesURL ?? Bundle.main.resourceURL else { return nil }
        let content = resources.appendingPathComponent("Content", isDirectory: true)
        var isDir: ObjCBool = false
        let fighters = content.appendingPathComponent("Fighters", isDirectory: true)
        guard FileManager.default.fileExists(atPath: fighters.path, isDirectory: &isDir), isDir.boolValue else {
            return nil
        }
        return content
    }

    public static func greyboxDirectory(fromFile file: String = #filePath) -> URL {
        fighterDirectory("greybox", fromFile: file)
    }

    public static func replaysDirectory(fromFile file: String = #filePath) -> URL {
        repoRoot(fromFile: file).appendingPathComponent("Fixtures/Replays", isDirectory: true)
    }

    public static func badFighterCaseDirectory(_ name: String, fromFile file: String = #filePath) -> URL {
        let testsRoot = URL(fileURLWithPath: file)
            .deletingLastPathComponent() // Contracts
            .deletingLastPathComponent() // FightCoreTests
        return testsRoot.appendingPathComponent("Resources/bad_fighters/\(name)", isDirectory: true)
    }
}