import SwiftUI

/// The liquid beneath a gooey path menu: one disc per petal plus the trigger,
/// merged by the goo shader.
///
/// The petals animate themselves with per-petal `KeyframeAnimator` timelines,
/// so their positions never exist in any one place. Rather than collect them,
/// this view runs a single linear clock per transition and evaluates every
/// petal's position analytically with `Spring.value` — the same spring, the
/// same per-petal delays (`GooMath.menuDelay` mirrors `PetalTimeline.make`) —
/// so discs and icons travel together without either driving the other.
struct GooMenuUnderlay: View {
    var count: Int
    /// Resting offset of each petal from the trigger's centre.
    var anchors: [CGSize]
    var triggerRadius: CGFloat
    var petalRadius: CGFloat
    var spring: Spring
    var duration: Double
    var stagger: Double
    var isOpen: Bool
    var highlightedIndex: Int?
    var smoothing: CGFloat
    var edge: CGFloat
    var fill: Color
    /// Side of the square canvas. Sized by the caller to contain the farthest
    /// overshoot plus a petal and the blend range.
    var extent: CGFloat

    /// The last petal to move plus its spring's settling; the clock runs a
    /// little past the nominal duration so the necks finish snapping.
    private var total: Double {
        duration + stagger * Double(max(count - 1, 0)) + 0.2
    }

    var body: some View {
        KeyframeAnimator(initialValue: total, trigger: isOpen) { elapsed in
            GooSurface(
                blobs: blobs(at: elapsed),
                smoothing: smoothing,
                edge: edge,
                fill: fill
            )
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                LinearKeyframe(0.0, duration: 1e-4)
                LinearKeyframe(total, duration: total)
            }
        }
        .frame(width: extent, height: extent)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func blobs(at elapsed: Double) -> [GooBlob] {
        let centre = CGPoint(x: extent / 2, y: extent / 2)
        var blobs: [GooBlob] = [GooBlob(center: centre, radius: triggerRadius)]

        for index in 0 ..< min(count, anchors.count) {
            let delay = GooMath.menuDelay(
                index: index, count: count, stagger: stagger, opening: isOpen
            )
            let t = elapsed - delay
            // Travel fraction along the petal's ray: 0 at home, 1 at rest,
            // transiently past 1 while the spring overshoots.
            let fraction: Double
            if t <= 0 {
                fraction = isOpen ? 0 : 1
            } else {
                fraction = spring.value(
                    fromValue: isOpen ? 0.0 : 1.0,
                    toValue: isOpen ? 1.0 : 0.0,
                    initialVelocity: 0,
                    time: t
                )
            }
            let radius = petalRadius * (highlightedIndex == index ? 1.14 : 1)
            blobs.append(GooBlob(
                center: CGPoint(
                    x: centre.x + anchors[index].width * fraction,
                    y: centre.y + anchors[index].height * fraction
                ),
                radius: radius
            ))
        }
        return blobs
    }
}
