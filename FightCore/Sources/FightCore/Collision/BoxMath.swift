struct WorldBox: Equatable {
    var left: Int32
    var right: Int32
    var bottom: Int32
    var top: Int32

    func overlaps(_ other: WorldBox) -> Bool {
        left < other.right
            && right > other.left
            && bottom < other.top
            && top > other.bottom
    }
}

enum BoxMath {
    static let scale = Fixed.scale

    static func mirrorX(_ box: Hitbox, facingRight: Bool) -> Hitbox {
        guard !facingRight else { return box }
        return Hitbox(x: -box.x - box.w, y: box.y, w: box.w, h: box.h)
    }

    static func worldBox(
        anchorX: Int32,
        anchorY: Int32,
        box: Hitbox,
        facingRight: Bool
    ) -> WorldBox {
        let local = mirrorX(box, facingRight: facingRight)
        let left = anchorX + local.x * scale
        let bottom = anchorY + local.y * scale
        let right = left + local.w * scale
        let top = bottom + local.h * scale
        return WorldBox(left: left, right: right, bottom: bottom, top: top)
    }

    static func horizontalOverlap(_ a: WorldBox, _ b: WorldBox) -> Int32 {
        let amount = min(a.right, b.right) - max(a.left, b.left)
        return amount > 0 ? amount : 0
    }
}