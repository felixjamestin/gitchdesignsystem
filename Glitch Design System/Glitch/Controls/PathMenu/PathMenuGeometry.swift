import CoreGraphics
import Foundation

// MARK: - Anchors

/// The three radii a single petal visits, as offsets from the trigger's centre.
struct PathMenuAnchors: Equatable, Sendable {
    /// Unit direction the petal travels in. Cached so radii can be rescaled without
    /// recomputing trigonometry.
    var direction: CGSize
    var near: CGSize
    var end: CGSize
    var far: CGSize
}

// MARK: - Geometry

/// Resting positions for every petal, derived once per (count, style) and cached.
///
/// This is a pure value with no SwiftUI dependency, which keeps the layout maths
/// out of the render loop and makes it verifiable on its own.
struct PathMenuGeometry: Equatable, Sendable {

    private(set) var anchors: [PathMenuAnchors]

    /// - Parameters:
    ///   - count: number of petals.
    ///   - wholeAngle: total sweep in radians.
    ///   - rotationOffset: rotation of the whole fan in radians.
    ///
    /// Mirrors `AwesomeMenu -_setMenu`: a full turn is shortened by one slice so the
    /// first and last petals do not land on top of each other, petals are then
    /// spaced evenly across the remaining sweep, and a petal at radius `r` sits at
    /// `(r·sin θ, −r·cos θ)`.
    ///
    /// The original rotated each point about the trigger with an affine transform.
    /// That is algebraically identical to adding the offset to `θ`, so it is folded
    /// into the angle here and costs nothing.
    init(
        count: Int,
        nearRadius: CGFloat,
        endRadius: CGFloat,
        farRadius: CGFloat,
        wholeAngle: Double,
        rotationOffset: Double
    ) {
        guard count > 0 else {
            anchors = []
            return
        }

        var sweep = wholeAngle
        if sweep >= 2 * .pi - .ulpOfOne {
            sweep -= sweep / Double(count)
        }

        // The original divides by `count - 1`, which is NaN for a single petal.
        let divisor = Double(max(count - 1, 1))

        anchors = (0 ..< count).map { index in
            let theta = Double(index) * sweep / divisor + rotationOffset
            let direction = CGSize(width: sin(theta), height: -cos(theta))
            return PathMenuAnchors(
                direction: direction,
                near: direction.scaled(by: nearRadius),
                end: direction.scaled(by: endRadius),
                far: direction.scaled(by: farRadius)
            )
        }
    }
}

// MARK: - Master clock

/// Turns one clock into every petal's own progress.
///
/// The self-animating petals each run their own keyframe timeline, which is
/// cheap and correct and tells the menu nothing about where any of them is. A
/// gooey surface has to know: the merged silhouette is built from the petals'
/// positions, and a blob drawn from stale positions slides off the icons it is
/// supposed to be carrying.
///
/// So on that path a single timeline runs at the container, and each petal's
/// progress is derived from it here. The delays reproduce exactly those
/// `PetalTimeline.make` computes — forwards on the way out, backwards on the way
/// home, as the original's countdown timer did — because switching surface must
/// not move the petals.
public struct PathMenuClock: Equatable, Sendable {

    public init() {}

    /// How long the whole transition takes, last petal included.
    public func totalDuration(count: Int, duration: Double, stagger: Double) -> Double {
        duration + stagger * Double(max(count - 1, 0))
    }

    /// One petal's own progress, `0` to `1`, at a given point on the master clock.
    public func petalProgress(
        master: Double,
        index: Int,
        count: Int,
        duration: Double,
        stagger: Double,
        reversed: Bool
    ) -> Double {
        guard duration > 0 else { return 1 }

        let total = totalDuration(count: count, duration: duration, stagger: stagger)
        let delay = stagger * Double(reversed ? max(count - 1 - index, 0) : index)
        let elapsed = master.clamped01 * total - delay

        return (elapsed / duration).clamped01
    }
}

private extension Double {
    var clamped01: Double { Swift.min(Swift.max(self, 0), 1) }
}

// MARK: - Petal path

/// The waypoints a petal travels through, held inline rather than in an array so
/// that sampling it every frame allocates nothing and stays in registers.
struct PetalPath: Equatable, Sendable {

    private var p0: CGSize
    private var p1: CGSize
    private var p2: CGSize
    private var p3: CGSize
    private var segments: Int

    init(_ a: CGSize) {
        p0 = a; p1 = a; p2 = a; p3 = a
        segments = 0
    }

    init(_ a: CGSize, _ b: CGSize) {
        p0 = a; p1 = b; p2 = b; p3 = b
        segments = 1
    }

    init(_ a: CGSize, _ b: CGSize, _ c: CGSize) {
        p0 = a; p1 = b; p2 = c; p3 = c
        segments = 2
    }

    init(_ a: CGSize, _ b: CGSize, _ c: CGSize, _ d: CGSize) {
        p0 = a; p1 = b; p2 = c; p3 = d
        segments = 3
    }

    /// Position at `progress`, where `0` is the first waypoint and `1` the last.
    ///
    /// Values outside `0...1` extrapolate along the nearest end segment, which is
    /// what lets a spring overshoot past the resting position and settle back.
    func point(at progress: Double) -> CGSize {
        guard segments > 0 else { return p0 }

        let scaled = progress * Double(segments)
        // `min(segments - 1, ...)` keeps the final segment selected past the end, so
        // overshoot extrapolates instead of clamping.
        let index = max(0, min(segments - 1, Int(scaled.rounded(.down))))
        let t = scaled - Double(index)

        switch index {
        case 0: return p0.interpolated(to: p1, t)
        case 1: return p1.interpolated(to: p2, t)
        default: return p2.interpolated(to: p3, t)
        }
    }
}

// MARK: - CGSize helpers

extension CGSize {
    func scaled(by factor: CGFloat) -> CGSize {
        CGSize(width: width * factor, height: height * factor)
    }

    func interpolated(to other: CGSize, _ t: Double) -> CGSize {
        CGSize(
            width: width + (other.width - width) * t,
            height: height + (other.height - height) * t
        )
    }

    var magnitude: CGFloat {
        (width * width + height * height).squareRoot()
    }

    func distance(to other: CGSize) -> CGFloat {
        CGSize(width: other.width - width, height: other.height - height).magnitude
    }
}
