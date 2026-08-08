import Foundation

/// Angle ↔ value mapping for rotary controls.
///
/// A dial maps a value onto an arc centred on straight-up, so `0` radians is
/// the middle of the range and the arc runs from `-sweep/2` to `+sweep/2`.
public enum GlitchAngleMath {

    /// 270° — the conventional knob arc, leaving a gap at the bottom so the
    /// minimum and maximum are visually distinguishable.
    public static let defaultSweep: Double = .pi * 1.5

    /// The value an arc position represents.
    ///
    /// Angles past either end of the arc clamp to the bounds. They must not
    /// wrap: a knob dragged hard clockwise should stop at maximum, not
    /// reappear at minimum.
    public static func value(
        forAngle radians: Double,
        sweep: Double,
        in range: ClosedRange<Double>
    ) -> Double {
        guard sweep > 0 else { return range.lowerBound }
        let t = GlitchValueMath.clamp((radians + sweep / 2) / sweep, to: 0...1)
        return GlitchValueMath.denormalize(t, in: range)
    }

    /// The arc position a value sits at. Inverse of `value(forAngle:sweep:in:)`.
    public static func angle(
        forValue value: Double,
        sweep: Double,
        in range: ClosedRange<Double>
    ) -> Double {
        guard sweep > 0 else { return 0 }
        return GlitchValueMath.normalize(value, in: range) * sweep - sweep / 2
    }

    /// The signed rotation from `a` to `b`, always taking the shorter way
    /// around and never exceeding a half turn.
    ///
    /// Dragging a knob across the ±π seam produces a raw difference of nearly a
    /// full turn. Used directly, the value would leap the whole range in one
    /// frame; this collapses that to the small rotation actually performed.
    public static func shortestDelta(from a: Double, to b: Double) -> Double {
        (b - a).remainder(dividingBy: 2 * .pi)
    }
}
