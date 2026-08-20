import SwiftUI

/// A scalloped bubble, the shape a thought arrives in.
///
/// Drawn as one closed outline rather than a pile of overlapping circles.
/// Circles are how a thought cloud is usually built, and they fill correctly,
/// but they cannot be *stroked*: every circle contributes its whole
/// circumference, so the interior arcs show and the bubble reads as a bunch of
/// grapes. Walking a single perimeter costs the same and strokes properly.
///
/// The perimeter is a superellipse rather than an ellipse, because a tooltip is
/// a wide, short box and an oval would cut the ends off its text. At an
/// exponent of four the base shape is already a rounded rectangle; the scallops
/// ride on top of it.
///
/// Deterministic for a given `seed`. Nothing here reads a clock or a global
/// generator, so a redraw produces the same cloud and only a new seed produces
/// a new one.
public struct GlitchThoughtCloud: InsettableShape {
    /// Picks the number of lobes and where they start. Two clouds with the
    /// same seed are the same cloud.
    public var seed: UInt64

    /// How deep the lobes are, as a fraction of the bubble's short half-axis.
    public var amplitude: Double

    private var insetAmount: CGFloat = 0

    public init(seed: UInt64, amplitude: Double = 0.3) {
        self.seed = seed
        self.amplitude = amplitude
    }

    /// Enough that the scallops read as curves at tooltip size and not as a
    /// polygon; few enough that a bubble is not thousands of line segments.
    private static let samples = 240
    /// Four is already a rounded rectangle; lower rounds it toward an oval.
    private static let exponent = 4.0

    public func path(in rect: CGRect) -> Path {
        let box = rect.insetBy(dx: insetAmount, dy: insetAmount)
        guard box.width > 0, box.height > 0 else { return Path() }

        let centre = CGPoint(x: box.midX, y: box.midY)
        // How far a lobe swings, in points rather than as a fraction of the
        // local radius. Relative depth looked right on a square and wrong on a
        // tooltip: the sides bulged while the long top and bottom stayed
        // nearly flat, because the radius they scale is so much smaller there.
        let depth = min(box.width, box.height) / 2 * amplitude
        let halfWidth = box.width / 2 - depth
        let halfHeight = box.height / 2 - depth
        guard halfWidth > 0, halfHeight > 0 else { return Path() }

        // The base outline: a superellipse rather than an ellipse, because a
        // tooltip is a wide, short box and an oval would cut the ends off its
        // text. At an exponent of four this is already a rounded rectangle.
        var base: [CGPoint] = []
        base.reserveCapacity(Self.samples + 1)
        for step in 0...Self.samples {
            let angle = Double(step) / Double(Self.samples) * 2 * .pi
            let reach = pow(
                pow(abs(cos(angle)), Self.exponent) + pow(abs(sin(angle)), Self.exponent),
                -1 / Self.exponent
            )
            base.append(CGPoint(
                x: centre.x + cos(angle) * reach * halfWidth,
                y: centre.y + sin(angle) * reach * halfHeight
            ))
        }

        // Lobes are spaced along the *perimeter*, not by angle. Spacing them
        // by angle is what made the first attempt read as a wobble: equal
        // steps of angle cover far more outline along a long side than a short
        // one, so the ends grew big lobes and the top and bottom stayed flat.
        var travelled: [Double] = [0]
        travelled.reserveCapacity(base.count)
        for index in 1..<base.count {
            let previous = base[index - 1], current = base[index]
            travelled.append(
                travelled[index - 1] + hypot(current.x - previous.x, current.y - previous.y)
            )
        }
        let perimeter = travelled[travelled.count - 1]
        guard perimeter > 0 else { return Path() }

        // Each lobe wants to be several times wider than it is deep. Lobes
        // as wide as they are deep looked like a comb: on a box this long and
        // this short the depth is capped by the short side, so a lobe that
        // rises its full depth over half its own width comes to a point.
        // The seed nudges the count and picks where the first one falls.
        var generator = SplitMix64(seed: seed)
        let natural = (perimeter / max(depth * 6, 1)).rounded()
        let nudged = natural + Double(Int(generator.next() % 5)) - 2
        // Odd, so no lobe has a twin directly opposite it — an even count
        // reads as machined rather than drawn.
        let lobes = max(5, nudged.rounded() / 2 * 2 + 1)
        let phase = Double(generator.next() % 3600) / 3600 * 2 * .pi

        var path = Path()
        for (index, point) in base.enumerated() {
            let along = travelled[index] / perimeter
            // `abs(sin)` rather than a sinusoid raised to sit above zero: a
            // sinusoid spends as long in its valleys as on its crests, which
            // gives a wave. This gives round crests meeting at narrow notches,
            // which is what a cloud is. The power flattens the crests a little
            // further toward the circular arcs they are standing in for.
            let scallop = pow(abs(sin(.pi * lobes * along + phase)), 0.7)

            // Pushed out along the radial direction. Close enough to the true
            // normal on a shape this convex, and it cannot fold the outline
            // back through itself the way a computed normal can at a corner.
            let dx = point.x - centre.x
            let dy = point.y - centre.y
            let length = max(hypot(dx, dy), 0.0001)
            let swelled = CGPoint(
                x: point.x + dx / length * depth * scallop,
                y: point.y + dy / length * depth * scallop
            )

            if index == 0 { path.move(to: swelled) } else { path.addLine(to: swelled) }
        }
        path.closeSubpath()

        return path
    }

    public func inset(by amount: CGFloat) -> Self {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

/// A small deterministic generator, so a cloud's shape depends on its seed and
/// nothing else.
///
/// `SystemRandomNumberGenerator` cannot do this — it has no seed — and
/// `Int.random(in:)` would re-roll on every redraw, which is the one thing a
/// shape must never do.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
