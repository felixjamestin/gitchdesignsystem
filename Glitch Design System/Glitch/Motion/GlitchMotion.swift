import SwiftUI

/// The system's entire animation vocabulary — four springs, resolved once and
/// read from the environment.
///
/// Controls must never declare their own animation. Every motion in the system
/// comes from here, which is what makes the global speed control in the Motion
/// Lab work without a single control knowing about it, and what makes Reduce
/// Motion a single change rather than an audit.
///
/// Springs only, never a fixed-duration curve: a spring can be redirected
/// mid-flight, so a control interrupted halfway through continues from where
/// it actually is instead of snapping and restarting.
public struct GlitchMotion: Equatable, Sendable {
    /// Presses, toggles, checkmarks — anything that should feel instant.
    public var snap: Animation
    /// Values settling after a drag.
    public var glide: Animation
    /// Things arriving: popovers, chips. Slight overshoot.
    public var pop: Animation
    /// Disclosure and ambient movement. Critically damped, no overshoot.
    public var drift: Animation

    /// `scale` stretches every response — 1.0 normal, 0.1 for inspection.
    /// `reduceMotion` collapses all four to a short opacity-friendly curve
    /// with no spring overshoot and no positional character.
    public static func resolve(scale: Double, reduceMotion: Bool) -> GlitchMotion {
        let s = max(0.05, scale)

        guard !reduceMotion else {
            let flat = Animation.easeOut(duration: 0.10 * s)
            return GlitchMotion(snap: flat, glide: flat, pop: flat, drift: flat)
        }

        return GlitchMotion(
            snap: .spring(response: 0.18 * s, dampingFraction: 0.86),
            glide: .spring(response: 0.32 * s, dampingFraction: 0.82),
            pop: .spring(response: 0.28 * s, dampingFraction: 0.68),
            drift: .spring(response: 0.50 * s, dampingFraction: 1.00)
        )
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
