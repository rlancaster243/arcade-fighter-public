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
        let data = try Data(contentsOf: dir.appendingPathComponent("stage.json"))
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
        return (StageBounds.playLeftPx, StageBounds.playRightPx)
    }

    public enum StageBoundsError: Error, CustomStringConvertible {
        case invalidStageJSON(String)

        public var description: String {
            switch self {
            case .invalidStageJSON(let id):
                return "invalid stage.json for \(id)"
            }
        }
    }
}