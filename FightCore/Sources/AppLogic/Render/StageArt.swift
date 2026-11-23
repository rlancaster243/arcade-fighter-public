import FightCore
import Foundation

/// One background layer of a stage, back to front by `zOrder`.
public struct StageLayerSpec: Sendable, Equatable {
    public var id: String
    public var imageURL: URL
    /// Scroll factor in 1/256ths of camera movement (256 = moves with the arena).
    public var parallaxQ8: Int32
    public var zOrder: Int32
    /// Texture pixels per logical scene pixel (stage.json top-level `texelScale`, default 1).
    public var texelScale: Int32

    public init(id: String, imageURL: URL, parallaxQ8: Int32, zOrder: Int32, texelScale: Int32 = 1) {
        self.id = id
        self.imageURL = imageURL
        self.parallaxQ8 = parallaxQ8
        self.zOrder = zOrder
        self.texelScale = max(texelScale, 1)
    }
}

/// Logical (scene-space) size of a stage layer.
public struct StageLayerSize: Sendable, Equatable {
    public var width: Double
    public var height: Double
}

/// Reads a stage bundle's art. Supports `layers` (stage2 schema) and the single
/// `background` image of the original stage1 schema (treated as one full-parallax layer).
public enum StageArt: Sendable {
    public static func layers(stageID: String, fromFile file: String = #filePath) throws -> [StageLayerSpec] {
        let dir = ContentPaths.stageDirectory(stageID, fromFile: file)
        let json = try StageBoundsLoader.loadStageJSON(stageID, fromFile: file)
        return layers(fromJSON: json, directory: dir)
    }

    /// Reads a `stage.json` file directly; layer images resolve beside it.
    public static func layers(fromStageJSON url: URL) throws -> [StageLayerSpec] {
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw StageBoundsLoader.StageBoundsError.invalidStageJSON(url.lastPathComponent)
        }
        return layers(fromJSON: json, directory: url.deletingLastPathComponent())
    }

    /// Parses an already-loaded `stage.json` object. `texelScale` is read once at the top level
    /// and applies to every layer; missing, non-integer or non-positive values mean 1.
    public static func layers(fromJSON json: [String: Any], directory dir: URL) -> [StageLayerSpec] {
        let texelScale = Int32(clamping: max((json["texelScale"] as? Int) ?? 1, 1))
        if let layers = json["layers"] as? [[String: Any]] {
            return layers.compactMap { layer -> StageLayerSpec? in
                guard let image = layer["image"] as? String else { return nil }
                return StageLayerSpec(
                    id: layer["id"] as? String ?? image,
                    imageURL: dir.appendingPathComponent(image),
                    parallaxQ8: Int32(clamping: layer["parallaxQ8"] as? Int ?? 256),
                    zOrder: Int32(clamping: layer["zOrder"] as? Int ?? 0),
                    texelScale: texelScale
                )
            }.sorted { $0.zOrder < $1.zOrder }
        }
        if let background = json["background"] as? String {
            return [StageLayerSpec(id: "background", imageURL: dir.appendingPathComponent(background),
                                   parallaxQ8: 256, zOrder: 0, texelScale: texelScale)]
        }
        return []
    }

    /// Scene-space size of a layer texture: pixels divided by `texelScale`.
    public static func logicalSize(pixelWidth: Int, pixelHeight: Int, texelScale: Int32) -> StageLayerSize {
        let scale = Double(max(texelScale, 1))
        return StageLayerSize(width: Double(pixelWidth) / scale, height: Double(pixelHeight) / scale)
    }

    /// Horizontal layer offset for a camera scroll (scene px).
    public static func layerOffsetX(scrollX: Int32, parallaxQ8: Int32) -> Int32 {
        -(scrollX * parallaxQ8) / 256
    }
}
