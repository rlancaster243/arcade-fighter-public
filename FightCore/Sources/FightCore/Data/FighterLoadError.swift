import Foundation

public enum FighterLoadError: Error, Equatable, Sendable {
    case wrongSchemaVersion(Int)
    case duplicateMoveID(String)
    case negativeFrameCount(String)
    case frameBoxCountMismatch(String)
    case missingSpriteName(String)
    case unblockableNonThrow(String)
    case emptyGamePlan
    case invalidGuard(String)
    case unknownState(String)
    case fileNotFound(String)
    case decodeFailed(String)
    case missingSheetFile
}