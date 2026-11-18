import Foundation
@testable import FightCore

enum L10ContentPaths {
    static func repoRoot(fromFile file: String = #filePath) -> URL {
        ContentPaths.repoRoot(fromFile: file)
    }

    static func ilseDirectory(fromFile file: String = #filePath) -> URL {
        repoRoot(fromFile: file).appendingPathComponent("Content/Fighters/ilse", isDirectory: true)
    }

    static func rookDirectory(fromFile file: String = #filePath) -> URL {
        repoRoot(fromFile: file).appendingPathComponent("Content/Fighters/rook", isDirectory: true)
    }

    static func stage2Directory(fromFile file: String = #filePath) -> URL {
        repoRoot(fromFile: file).appendingPathComponent("Content/Stages/stage2", isDirectory: true)
    }

    static func audioDirectory(fromFile file: String = #filePath) -> URL {
        repoRoot(fromFile: file).appendingPathComponent("Content/Audio", isDirectory: true)
    }
}