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
            sheet = try decoder.decode([SheetFrameJSON].self, from: sheetData)
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
        repoRoot root: URL? = nil
    ) -> URL {
        let root = root ?? repoRoot(fromFile: file)
        return root
            .appendingPathComponent("Content/Fighters/\(id)/\(id).contentbundle", isDirectory: true)
    }

    public static func stageDirectory(_ id: String, fromFile file: String = #filePath) -> URL {
        repoRoot(fromFile: file)
            .appendingPathComponent("Content/Stages/\(id)/\(id).contentbundle", isDirectory: true)
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