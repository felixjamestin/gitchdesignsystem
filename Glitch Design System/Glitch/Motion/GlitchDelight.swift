import SwiftUI

/// The switch for everything borrowed from game feel.
///
/// These are the effects that make a control feel like an object rather than a
/// widget — hit-stop at the limits, a ghost of where a value came from,
/// inertia in the fill, notches that announce themselves, panels that unroll.
/// None of them changes what a control *does*: every value you can reach with
/// them on you can reach with them off, and the maths is identical either way.
///
/// They are separable for two honest reasons. Effects tuned for delight are
/// exactly the effects that grate on the hundredth use, and someone shipping a
/// dense professional tool may reasonably want the plain version. And a user
/// who finds motion distracting deserves an off switch that isn't the
/// accessibility setting — Reduce Motion already suppresses the positional
/// parts, but this removes the embellishment entirely.
extension EnvironmentValues {
    @Entry public var glitchDelight: Bool = true
}

extension View {
    /// Turns the game-feel layer on or off for this subtree.
    public func glitchDelight(_ isEnabled: Bool) -> some View {
        environment(\.glitchDelight, isEnabled)
    }
}

/// Tuning for the game-feel layer, kept together so the numbers can be
/// compared against each other rather than hunted through call sites.
public enum GlitchDelightTuning {
    /// How long a value freezes on arriving at a limit.
    ///
    /// Borrowed from fighting games, where the same trick sells a hit. The
    /// pause has to be long enough to register as a stop and short enough that
    /// it never reads as the control having missed an event — around three
    /// frames.
    public static let hitStop: Duration = .milliseconds(55)

    /// How far the fill lags behind a fast drag, in points. Small: this is
    /// inertia, not latency, and the difference is entirely one of degree.
    public static let maxFillTrail: CGFloat = 2.5

    /// Drag velocity, in points per second, that produces the full trail.
    public static let trailReferenceVelocity: CGFloat = 900

    /// How close the value must be, as a fraction of the range, for a notch to
    /// light up. Wider than the magnetic pull itself, so the notch announces
    /// itself before it grabs.
    public static let notchProximity: Double = 0.05

    /// Opening opacity of the ghost left behind by a jump.
    public static let ghostOpacity: Double = 0.55
}
