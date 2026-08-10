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
    /// The furthest a track will ever stretch past its own edge.
    ///
    /// Named because containers have to know it. A row that grows by this much
    /// needs whatever contains it to let the overhang through; clip it and the
    /// stretch is cut flat, so the track's rounded end reads as a torn edge at
    /// exactly the moment the limit is being announced. `GlitchRowClip` takes
    /// its horizontal slack from here so the two cannot drift apart.
    public static let maximumTrackOverscroll: Double = 8

    public static func trackOverscroll(
        pastEdge distance: Double,
        deadZone: Double = 32,
        ramp: Double = 200,
        maximum: Double = maximumTrackOverscroll
    ) -> Double {
        let beyond = max(0, distance - deadZone)
        guard beyond > 0, ramp > 0 else { return 0 }
        return maximum * (min(beyond / ramp, 1)).squareRoot()
    }

    /// The notches a slider shows, as fractions of its track.
    ///
    /// One per step while the range is coarse enough for that to stay
    /// readable, and every 10% once it isn't. The same list drives the drawn
    /// hashmarks and every kind of snapping, so what you see is exactly what
    /// you can land on.
    ///
    /// The bounds are excluded: the ends of the track already mark themselves.
    public static func notchFractions(
        in range: ClosedRange<Double>,
        step: Double
    ) -> [Double] {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return [] }

        if step > 0, span / step <= 10 + 1e-9 {
            let count = Int((span / step).rounded()) - 1
            guard count > 0 else { return [] }
            return (1...count).map { Double($0) * step / span }
        }
        return (1...9).map { Double($0) / 10 }
    }

    /// The notch closest to `value`, including the range's own bounds — which
    /// aren't drawn, but are the most useful positions to be able to hit.
    public static func nearestNotch(
        to value: Double,
        in range: ClosedRange<Double>,
        step: Double
    ) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return range.lowerBound }

        let fraction = normalize(value, in: range)
        let candidates = [0] + notchFractions(in: range, step: step) + [1]
        let nearest = candidates.min { abs($0 - fraction) < abs($1 - fraction) } ?? fraction
        return denormalize(nearest, in: range)
    }

    /// Pulls `value` onto a notch when it is within `tolerance` of one, and
    /// otherwise leaves it exactly where it is.
    ///
    /// `tolerance` is a fraction of the whole range, so the pull covers the
    /// same proportion of the track whatever the units. Zero disables it.
    public static func magnetize(
        _ value: Double,
        in range: ClosedRange<Double>,
        step: Double,
        tolerance: Double
    ) -> Double {
        guard tolerance > 0 else { return clamp(value, to: range) }

        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return range.lowerBound }

        let notch = nearestNotch(to: value, in: range, step: step)
        guard abs(notch - value) / span <= tolerance else { return clamp(value, to: range) }
        return notch
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
        return magnetize(value, in: range, step: step, tolerance: tolerance)
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
