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
