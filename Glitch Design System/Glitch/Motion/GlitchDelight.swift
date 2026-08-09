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
    ///
    /// Also mirrors the setting into `GlitchSound`, which is global because
    /// there is only one speaker — a per-subtree environment read would let
    /// two halves of a screen disagree about whether the app makes noise.
    public func glitchDelight(_ isEnabled: Bool) -> some View {
        environment(\.glitchDelight, isEnabled)
            .onChange(of: isEnabled, initial: true) { _, enabled in
                GlitchSound.isEnabled = enabled
            }
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
    /// begin reacting. Several times wider than the 2% magnetic pull, so the
    /// notch has room to grow visibly before it grabs — foreshadowing that
    /// only starts once the pull is imminent isn't foreshadowing.
    public static let notchProximity: Double = 0.09

    /// How far the approaching notch takes on the handle's colour.
    ///
    /// Brightness is the *only* thing that changes — the mark keeps its size,
    /// so nothing shifts under the eye while you are aiming at it. Well short
    /// of the handle's own strength, too: the notch is announcing what is
    /// *about* to happen, and something arriving at full brightness has
    /// nothing left to say when the value actually lands on it.
    public static let notchHighlightOpacity: Double = 0.45

    /// Shapes the approach. Above 1 the brightening eases *in* — barely there
    /// across most of the run and gathering quickly at the end, so the notch
    /// reads as something the value is falling towards rather than a lamp
    /// switching on at a fixed distance.
    public static let notchApproachCurve: Double = 2.2

    /// Opening opacity of the ghost left behind by a jump.
    public static let ghostOpacity: Double = 0.55

    // MARK: Anticipation and landing

    /// How far the fill pulls back before a jump, in points.
    public static let anticipation: CGFloat = 2
    /// How long it holds there. Long enough to see, too short to wait for.
    public static let anticipationHold: Duration = .milliseconds(45)
    /// Vertical scale of the handle at the moment a value lands; the
    /// horizontal scale takes the complementary amount, conserving area the
    /// way squash and stretch is supposed to.
    public static let landingSquash: CGFloat = 0.82
    /// Lateral kick when a typed value is rejected.
    public static let rejectionKick: CGFloat = 4

    // MARK: Forgiveness

    /// How long after a release a new press still counts as the same drag.
    ///
    /// Kept well under the ~150ms that reads as forgiving rather than sloppy.
    /// A finger that lifted this recently was mid-adjustment, not finished.
    public static let releaseLatch: Duration = .milliseconds(140)
    /// And how far away it may land, in points, to still count.
    public static let releaseLatchDistance: CGFloat = 24
    /// Two clicks inside this window mean "let me type it".
    public static let doubleClickWindow: Duration = .milliseconds(260)
    /// Fine mode disengages at this fraction of the distance that engaged it,
    /// so a wobbling hand cannot flicker between gears.
    public static let fineExitRatio: CGFloat = 0.6
    /// How much slower fine adjustment moves.
    public static let fineScale: Double = 0.15
}
