/// Integer upscale and letterbox offsets for a viewport around the 384×216 scene.
public struct ViewScale: Sendable, Equatable, Hashable {
    public var scale: Int32
    public var viewportWidth: Int32
    public var viewportHeight: Int32
    public var contentOffsetX: Int32
    public var contentOffsetY: Int32
    public var contentWidth: Int32
    public var contentHeight: Int32

    public init(
        scale: Int32,
        viewportWidth: Int32,
        viewportHeight: Int32,
        contentOffsetX: Int32,
        contentOffsetY: Int32,
        contentWidth: Int32,
        contentHeight: Int32
    ) {
        self.scale = scale
        self.viewportWidth = viewportWidth
        self.viewportHeight = viewportHeight
        self.contentOffsetX = contentOffsetX
        self.contentOffsetY = contentOffsetY
        self.contentWidth = contentWidth
        self.contentHeight = contentHeight
    }
}

public enum ViewScaleMath: Sendable {
  public static func largestIntegerScale(viewportWidth: Int32, viewportHeight: Int32) -> ViewScale {
      let w = max(viewportWidth, 1)
      let h = max(viewportHeight, 1)
      let scaleX = w / SceneConstants.width
      let scaleY = h / SceneConstants.height
      var scale = min(scaleX, scaleY)
      if scale < 1 { scale = 1 }
      let contentWidth = SceneConstants.width * scale
      let contentHeight = SceneConstants.height * scale
      let contentOffsetX = (w - contentWidth) / 2
      let contentOffsetY = (h - contentHeight) / 2
      return ViewScale(
          scale: scale,
          viewportWidth: w,
          viewportHeight: h,
          contentOffsetX: contentOffsetX,
          contentOffsetY: contentOffsetY,
          contentWidth: contentWidth,
          contentHeight: contentHeight
      )
  }
}