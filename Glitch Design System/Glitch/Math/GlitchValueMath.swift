/// Pure value and geometry math shared by every Glitch control.
///
/// Deliberately free of SwiftUI so it can be compiled and unit-tested by the
/// `GlitchMath` SPM target. Every function here is total: no input — including
/// degenerate ranges and zero-size layouts — may produce `NaN` or trap.
public enum GlitchValueMath {

    /// Constrains `v` to `range`.
    public static func clamp(_ v: Double, to range: ClosedRange<Double>) -> Double {
        min(max(v, range.lowerBound), range.upperBound)
    }

    /// Maps `v` onto `0...1` within `range`.
    ///
    /// A zero-width range would divide by zero — the classic custom-slider
    /// crash — so it resolves to `1`, rendering as a full track.
    public static func normalize(_ v: Double, in range: ClosedRange<Double>) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 1 }
        return clamp((v - range.lowerBound) / span, to: 0...1)
    }

    /// Maps a `0...1` fraction back onto `range`.
    public static func denormalize(_ t: Double, in range: ClosedRange<Double>) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return range.lowerBound }
        return range.lowerBound + clamp(t, to: 0...1) * span
    }

    /// The `0...1` position of `x` across `width`.
    ///
    /// Layout can report a zero width for a frame before it has been measured;
    /// dividing by it would poison every downstream value with `NaN`.
    public static func fraction(ofX x: Double, width: Double) -> Double {
        guard width > 0 else { return 0 }
        return clamp(x / width, to: 0...1)
    }

    /// Rounds `v` to the nearest multiple of `step`, measured from the range's
    /// lower bound, then constrains the result to `range`.
    ///
    /// The range wins: when the nearest step falls outside it, the clamped
    /// bound is returned even though it is not a multiple of `step`.
    /// A non-positive `step` means "continuous" and only clamps.
    public static func snap(_ v: Double, step: Double, in range: ClosedRange<Double>) -> Double {
        guard step > 0 else { return clamp(v, to: range) }
        let steps = ((v - range.lowerBound) / step).rounded()
        return clamp(range.lowerBound + steps * step, to: range)
    }

    /// How far the track itself stretches when the pointer is dragged beyond
    /// its end.
    ///
    /// Three deliberate properties, taken from the reference panel:
    ///
    /// - Nothing happens for the first `deadZone` points. Overshooting a
    ///   limit by a few pixels is almost always an accident of aim, and
    ///   responding to it would make every drag that ends near the edge
    ///   twitch.
    /// - Past that, travel follows a square root, so the first points of
    ///   resistance are the most visible and it flattens out from there.
    /// - It saturates at `maximum`. The stretch is a signal, not a distance
    ///   to be measured, and an unbounded one would tear the layout apart.
    public static func trackOverscroll(
        pastEdge distance: Double,
        deadZone: Double = 32,
        ramp: Double = 200,
        maximum: Double = 8
    ) -> Double {
        let beyond = max(0, distance - deadZone)
        guard beyond > 0, ramp > 0 else { return 0 }
        return maximum * (min(beyond / ramp, 1)).squareRoot()
    }

    /// Where a click — as opposed to a drag — should land.
    ///
    /// A drag is a continuous statement of intent and is taken literally. A
    /// click is a single guess at a position, so it is helped toward a tick:
    ///
    /// - When the range has ten or fewer steps every step has its own tick,
    ///   so the click simply snaps to the nearest one.
    /// - Otherwise the ticks sit every 10%, and a click within `tolerance` of
    ///   one is pulled onto it. Further away the exact position is kept,
    ///   because the user was evidently aiming between ticks.
    public static func snapToClick(
        _ value: Double,
        in range: ClosedRange<Double>,
        step: Double,
        tolerance: Double = 0.03125
    ) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return range.lowerBound }

        if step > 0, span / step <= 10 + 1e-9 {
            return snap(value, step: step, in: range)
        }

        let fraction = (value - range.lowerBound) / span
        let nearestTick = (fraction * 10).rounded() / 10
        guard abs(fraction - nearestTick) <= tolerance else {
            return clamp(value, to: range)
        }
        return clamp(range.lowerBound + nearestTick * span, to: range)
    }

    /// Diminishing-returns resistance for dragging past a limit.
    ///
    /// Returns a displacement smaller than `overshoot` that grows ever more
    /// slowly, so a limit is felt as resistance rather than a dead stop.
    /// Sign-preserving, and `0` for a zero `dimension`.
    public static func rubberBand(
        _ overshoot: Double,
        dimension: Double,
        coefficient: Double = 0.55
    ) -> Double {
        guard dimension > 0, overshoot != 0 else { return 0 }
        let magnitude = abs(overshoot)
        let resisted = (1 - (1 / (magnitude * coefficient / dimension + 1))) * dimension
        return overshoot < 0 ? -resisted : resisted
    }
}
