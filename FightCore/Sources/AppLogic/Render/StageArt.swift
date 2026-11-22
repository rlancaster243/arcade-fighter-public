import FightCore
import Foundation

/// One background layer of a stage, back to front by `zOrder`.
public struct StageLayerSpec: Sendable, Equatable {
    public var id: String
    public var imageURL: URL
    /// Scroll factor in 1/256ths of camera movement (256 = moves with the arena).
    public var parallaxQ8: Int32
    public var zOrder: Int32
}

/// Reads a stage bundle's art. Supports `layers` (stage2 schema) and the single
/// `background` image of the original stage1 schema (treated as one full-parallax layer).
public enum StageArt: Sendable {
    public static func layers(stageID: String, fromFile file: String = #filePath) throws -> [StageLayerSpec] {
        let dir = ContentPaths.stageDirectory(stageID, fromFile: file)
        let json = try StageBoundsLoader.loadStageJSON(stageID, fromFile: file)
        if let layers = json["layers"] as? [[String: Any]] {
            return layers.compactMap { layer -> StageLayerSpec? in
                guard let image = layer["image"] as? String else { return nil }
                return StageLayerSpec(
                    id: layer["id"] as? String ?? image,
                    imageURL: dir.appendingPathComponent(image),
                    parallaxQ8: Int32(layer["parallaxQ8"] as? Int ?? 256),
                    zOrder: Int32(layer["zOrder"] as? Int ?? 0)
                )
            }.sorted { $0.zOrder < $1.zOrder }
        }
        if let background = json["background"] as? String {
            return [StageLayerSpec(id: "background", imageURL: dir.appendingPathComponent(background),
                                   parallaxQ8: 256, zOrder: 0)]
        }
        return []
    }

    /// Horizontal layer offset for a camera scroll (scene px).
    public static func layerOffsetX(scrollX: Int32, parallaxQ8: Int32) -> Int32 {
        -(scrollX * parallaxQ8) / 256
    }
}
