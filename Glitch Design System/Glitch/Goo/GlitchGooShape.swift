import CoreGraphics

/// A shape the goo layer can merge.
///
/// Rounded rectangles only. A capsule is one whose corner radius has reached its
/// half-height, and a circle is a capsule whose sides have closed up — so both
/// effects in the system are expressible without the kernel needing a second
/// primitive, or a branch to choose between them.
///
/// Centres are relative to whatever the owning control treats as its origin;
/// `GlitchGooLayer` shifts them into its own coordinates before packing, so
/// nothing that builds a shape has to know where the layer sits.
public struct GlitchGooShape: Equatable, Sendable {

    public var center: CGPoint
    public var size: CGSize
    public var cornerRadius: CGFloat

    public init(center: CGPoint, size: CGSize, cornerRadius: CGFloat) {
        self.center = center
        self.size = size
        // A radius past half the shorter side has no meaning, and the distance
        // function returns nonsense rather than clamping for us.
        self.cornerRadius = min(cornerRadius, min(size.width, size.height) / 2)
    }

    public static func circle(center: CGPoint, diameter: CGFloat) -> Self {
        Self(
            center: center,
            size: CGSize(width: diameter, height: diameter),
            cornerRadius: diameter / 2
        )
    }

    public static func capsule(center: CGPoint, size: CGSize) -> Self {
        Self(center: center, size: size, cornerRadius: size.height / 2)
    }

    /// The same shape moved, which is all the animating controls ever do to one.
    public func offset(by delta: CGSize) -> Self {
        var moved = self
        moved.center = CGPoint(x: center.x + delta.width, y: center.y + delta.height)
        return moved
    }
}
