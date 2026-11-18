import Foundation
@testable import FightCore

enum L10ContentPaths {
    static func repoRoot(fromFile file: String = #filePath) -> URL {
        ContentPaths.repoRoot(fromFile: file)
    }

    static func ilseDirectory(fromFile file: String = #filePath) -> URL {
        ContentPaths.fighterDirectory("ilse", fromFile: file)
    }

    static func rookDirectory(fromFile file: String = #filePath) -> URL {
        ContentPaths.fighterDirectory("rook", fromFile: file)
    }

    static func stage2Directory(fromFile file: String = #filePath) -> URL {
        ContentPaths.stageDirectory("stage2", fromFile: file)
    }

    static func audioDirectory(fromFile file: String = #filePath) -> URL {
        repoRoot(fromFile: file).appendingPathComponent("Content/Audio", isDirectory: true)
    }
}