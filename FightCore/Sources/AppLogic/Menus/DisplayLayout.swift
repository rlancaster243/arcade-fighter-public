/// Letterbox and integer-scale math for 384×216 logical scene in window or fullscreen.
public enum DisplayLayout: Sendable, Equatable {
    public static let designWidth = DisplayPreferences.designWidth
    public static let designHeight = DisplayPreferences.designHeight

    public struct Viewport: Sendable, Equatable, Hashable {
        public var integerScale: Int
        public var contentWidth: Int
        public var contentHeight: Int
        public var offsetX: Int
        public var offsetY: Int

        public init(integerScale: Int, contentWidth: Int, contentHeight: Int, offsetX: Int, offsetY: Int) {
            self.integerScale = integerScale
            self.contentWidth = contentWidth
            self.contentHeight = contentHeight
            self.offsetX = offsetX
            self.offsetY = offsetY
        }
    }

    /// Largest integer scale that fits inside `viewWidth`×`viewHeight`.
    public static func viewport(viewWidth: Int, viewHeight: Int, forcedScale: Int? = nil) -> Viewport {
        let scale: Int
        if let forced = forcedScale, forced > 0 {
            scale = forced
        } else {
            let scaleW = viewWidth / designWidth
            let scaleH = viewHeight / designHeight
            scale = max(1, min(scaleW, scaleH))
        }
        let contentWidth = designWidth * scale
        let contentHeight = designHeight * scale
        let offsetX = (viewWidth - contentWidth) / 2
        let offsetY = (viewHeight - contentHeight) / 2
        return Viewport(
            integerScale: scale,
            contentWidth: contentWidth,
            contentHeight: contentHeight,
            offsetX: offsetX,
            offsetY: offsetY
        )
    }

    public static func minWindowSize(scale: Int) -> (width: Int, height: Int) {
        let s = max(1, scale)
        return (designWidth * s, designHeight * s)
    }
}