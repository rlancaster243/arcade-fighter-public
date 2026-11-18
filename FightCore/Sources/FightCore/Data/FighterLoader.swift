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
    public static func repoRoot(fromFile file: String = #filePath) -> URL {
        var url = URL(fileURLWithPath: file)
        for _ in 0..<5 {
            url.deleteLastPathComponent()
        }
        return url
    }

    public static func greyboxDirectory(fromFile file: String = #filePath) -> URL {
        repoRoot(fromFile: file).appendingPathComponent("Content/Fighters/greybox", isDirectory: true)
    }

    public static func replaysDirectory(fromFile file: String = #filePath) -> URL {
        repoRoot(fromFile: file).appendingPathComponent("Fixtures/Replays", isDirectory: true)
    }
}