import SwiftUI

/// The system's entire animation vocabulary, resolved once and read from the
/// environment.
///
/// Controls must never declare their own animation. Every motion in the system
/// comes from here, which is what makes the global speed control in the Motion
/// Lab work without a single control knowing about it, and what makes Reduce
/// Motion a single change rather than an audit.
///
/// The five values below are the reference panel's own spring configurations,
/// carried over exactly. Four are springs, because a spring can be redirected
/// mid-flight; the fifth is a plain curve, because it only ever animates color
/// and opacity, where there is no momentum to preserve.
public struct GlitchMotion: Equatable, Sendable {
    /// Segmented pill travel, and quick state changes. (spring 0.20 / 0.15)
    public var snap: Animation
    /// A value settling to a position you clicked. (spring 300 / 25 / 0.8)
    public var glide: Animation
    /// The slider handle revealing itself. (spring 0.25 / 0.15)
    public var pop: Animation
    /// Overscroll releasing, and section disclosure. (spring 0.35 / 0.15)
    public var drift: Animation
    /// Color and opacity crossfades only. (ease-out 0.15s)
    public var tint: Animation

    /// Seconds between one staggered sibling and the next. Zero under Reduce
    /// Motion, which collapses a stagger into a single simultaneous change.
    public var staggerDelay: Double

    /// `scale` stretches every duration — 1.0 normal, 0.1 for inspection.
    /// `reduceMotion` collapses all five to a short curve with no spring
    /// overshoot and no positional character.
    ///
    /// The bounce figures are deliberately higher than the reference panel's,
    /// which is critically damped to the point of feeling struck rather than
    /// sprung. Overshoot is what makes a value look like it has mass; the
    /// amounts here are small enough to read as weight rather than as wobble.
    public static func resolve(scale: Double, reduceMotion: Bool) -> GlitchMotion {
        let s = max(0.05, scale)

        guard !reduceMotion else {
            let flat = Animation.easeOut(duration: 0.10 * s)
            return GlitchMotion(
                snap: flat, glide: flat, pop: flat, drift: flat, tint: flat,
                staggerDelay: 0
            )
        }

        return GlitchMotion(
            snap: .spring(duration: 0.22 * s, bounce: 0.22),
            // The Doherty threshold puts the boundary between "responding to
            // me" and "making me wait" at 400ms. `glide` is the token on the
            // commit path — the one animation a user is actually waiting on
            // before they can judge a value — so it stays comfortably under.
            glide: .spring(duration: 0.36 * s, bounce: 0.34),
            pop: .spring(duration: 0.28 * s, bounce: 0.30),
            drift: .spring(duration: 0.40 * s, bounce: 0.28),
            tint: .easeOut(duration: 0.15 * s),
            staggerDelay: 0.035 * s
        )
    }

    /// A token delayed by its position in a staggered group.
    public func staggered(_ animation: Animation, index: Int) -> Animation {
        guard staggerDelay > 0, index > 0 else { return animation }
        return animation.delay(staggerDelay * Double(index))
    }

    public static let standard = GlitchMotion.resolve(scale: 1, reduceMotion: false)
}

extension EnvironmentValues {
    @Entry public var glitchMotion: GlitchMotion = .standard
    /// Exposed separately so the Motion Lab can bind a slider straight to it.
    @Entry public var glitchMotionScale: Double = 1.0
}

private struct GlitchMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var scale: Double
    var forceReduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .environment(\.glitchMotionScale, scale)
            .environment(
                \.glitchMotion,
                .resolve(scale: scale, reduceMotion: systemReduceMotion || forceReduceMotion)
            )
    }
}

extension View {
    /// Installs the resolved motion tokens for this subtree.
    ///
    /// The system Reduce Motion setting is always honoured; `reduceMotion`
    /// only forces it on, so the Motion Lab's override can't defeat it.
    public func glitchMotion(scale: Double = 1, reduceMotion: Bool = false) -> some View {
        modifier(GlitchMotionModifier(scale: scale, forceReduceMotion: reduceMotion))
    }
}
