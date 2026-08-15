import CoreGraphics

/// One blob of goo: a horizontal stadium — a capsule whose straight section
/// runs along x — or, with `halfLength` zero, a circle.
public struct GooBlob: Equatable, Sendable {
    public var center: CGPoint
    public var halfLength: CGFloat
    public var radius: CGFloat

    public init(center: CGPoint, halfLength: CGFloat = 0, radius: CGFloat) {
        self.center = center
        self.halfLength = halfLength
        self.radius = radius
    }
}

/// The goo renderer's geometry, mirrored from `Goo.metal` so the field the
/// shader evaluates per pixel can be verified here without a GPU.
public enum GooMath {

    /// Signed distance from `point` to a stadium: negative inside, zero on the
    /// surface, positive outside.
    public static func stadiumDistance(
        _ point: CGPoint,
        center: CGPoint,
        halfLength: CGFloat,
        radius: CGFloat
    ) -> CGFloat {
        let nearestX = min(max(point.x, center.x - halfLength), center.x + halfLength)
        let dx = point.x - nearestX
        let dy = point.y - center.y
        return (dx * dx + dy * dy).squareRoot() - radius
    }

    /// Polynomial smooth minimum (Quilez). `k` is the blend range in points:
    /// distances within `k` of each other melt together, which is what pulls a
    /// neck of liquid between two nearby blobs. Zero is a hard union.
    public static func smoothMin(_ a: CGFloat, _ b: CGFloat, k: CGFloat) -> CGFloat {
        guard k > 0 else { return min(a, b) }
        let h = min(max(0.5 + 0.5 * (b - a) / k, 0), 1)
        return b + (a - b) * h - k * h * (1 - h)
    }

    /// Blob layout for `GlitchGooField`: a capsule filling the control minus
    /// the room the button needs, and a submit blob that starts flush inside
    /// the capsule's trailing end and detaches by `progress`.
    ///
    /// The footprint is constant: at rest the trailing margin is simply empty,
    /// so focusing never reflows the text or the neighbours.
    public static func fieldBlobs(
        in size: CGSize,
        buttonDiameter: CGFloat,
        detachDistance: CGFloat,
        progress: CGFloat
    ) -> [GooBlob] {
        let fieldRadius = size.height / 2
        let reach = detachDistance + buttonDiameter
        let capsuleWidth = max(size.width - reach, size.height)
        let capsule = GooBlob(
            center: CGPoint(x: capsuleWidth / 2, y: fieldRadius),
            halfLength: max(capsuleWidth / 2 - fieldRadius, 0),
            radius: fieldRadius
        )

        let buttonRadius = buttonDiameter / 2
        let mergedX = capsuleWidth - buttonRadius
        let detachedX = capsuleWidth + detachDistance + buttonRadius
        let button = GooBlob(
            center: CGPoint(x: mergedX + (detachedX - mergedX) * progress, y: fieldRadius),
            radius: buttonRadius
        )
        return [capsule, button]
    }

    /// Stagger delay for petal `index` of the gooey menu. Petals leave
    /// first-to-last and return last-to-first, as the original menu's timer
    /// counted — the same delays `PetalTimeline.make` computes.
    public static func menuDelay(
        index: Int,
        count: Int,
        stagger: Double,
        opening: Bool
    ) -> Double {
        opening ? Double(index) * stagger : Double(count - 1 - index) * stagger
    }
}
