import Foundation

/// Resolves shipped `stage.json` play bounds into match collision space (arena-center origin).
public enum StageBoundsLoader {
    public static let shippedStageIDs = ["stage1", "stage2"]
    private static let arenaCenterPx: Int32 = 192

    public static func stageID(forSetupIndex index: Int) -> String {
        let ids = shippedStageIDs
        guard !ids.isEmpty else { return "stage1" }
        let clamped = min(max(0, index), ids.count - 1)
        return ids[clamped]
    }

    public static func loadStageJSON(_ id: String, fromFile file: String = #filePath) throws -> [String: Any] {
        let dir = ContentPaths.stageDirectory(id, fromFile: file)
        let jsonURL = dir.appendingPathComponent("stage.json")
        let data: Data
        do {
            data = try Data(contentsOf: jsonURL)
        } catch {
            throw StageBoundsError.stageFileUnreadable(id, underlying: error)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw StageBoundsError.invalidStageJSON(id)
        }
        return json
    }

    public static func playBounds(
        stageId: String,
        fromFile file: String = #filePath
    ) throws -> (playLeftPx: Int32, playRightPx: Int32) {
        let json = try loadStageJSON(stageId, fromFile: file)
        if let left = json["leftBound"] as? Int, let right = json["rightBound"] as? Int {
            return (Int32(left) - arenaCenterPx, Int32(right) - arenaCenterPx)
        }
        if let camera = json["cameraBounds"] as? [String: Any],
           let left = camera["left"] as? Int,
           let right = camera["right"] as? Int
        {
            return (Int32(left) - arenaCenterPx, Int32(right) - arenaCenterPx)
        }
        throw StageBoundsError.missingPlayBounds(stageId)
    }

    public enum StageBoundsError: Error, CustomStringConvertible {
        case stageFileUnreadable(String, underlying: Error)
        case invalidStageJSON(String)
        case missingPlayBounds(String)

        public var description: String {
            switch self {
            case .stageFileUnreadable(let id, let underlying):
                return "could not read stage.json for \(id): \(underlying)"
            case .invalidStageJSON(let id):
                return "invalid stage.json for \(id)"
            case .missingPlayBounds(let id):
                return "stage \(id) has no leftBound/rightBound or cameraBounds play space"
            }
        }
    }
}