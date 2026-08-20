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
    /// Whole views moving: switching tabs, pushing screens.
    ///
    /// Its own token because none of the others is meant for something the
    /// size of a screen, and stretching one of them to cover it would
    /// compromise what it was tuned for.
    ///
    /// Deliberately *less* bouncy than `glide`, despite moving further. A
    /// small element overshooting reads as lively; a whole screen doing the
    /// same amount reads as unstable, because the absolute distance it
    /// travels past its destination scales with its size.
    public var travel: Animation
    /// Something leaving under its own steam — a label rising away and fading.
    ///
    /// Long by this system's standards, because it is the only motion nobody
    /// is waiting on: it has already told you what it had to say, and the
    /// drift afterwards is the part you enjoy rather than the part you read.
    public var float: Animation
    /// Color and opacity crossfades only. (ease-out 0.15s)
    public var tint: Animation
    /// Something small arriving under its own steam and landing with a kick.
    ///
    /// The bounciest token in the system, and deliberately so: it is for
    /// things that appear beside what you are already looking at — a tooltip,
    /// a badge — where the overshoot is what draws the eye without a colour
    /// change or a sound. Too much for anything you have to read immediately
    /// afterwards at a fixed position, which is why `drift` still exists.
    public var bounce: Animation

    /// How far, in degrees, something arriving on `bounce` may lean.
    ///
    /// A budget rather than an angle: whatever arrives picks its own lean
    /// inside it, so no two arrivals are quite alike. Zero under Reduce
    /// Motion, which is what turns the whole effect back into a fade without
    /// any component testing for it.
    public var arrivalTilt: Double

    /// Seconds between one staggered sibling and the next. Zero under Reduce
    /// Motion, which collapses a stagger into a single simultaneous change.
    public var staggerDelay: Double

    /// `travel` expressed as raw spring parameters.
    ///
    /// For components that take response and damping rather than an
    /// `Animation` — the path menu drives its petals through a keyframe
    /// timeline and needs the numbers, not the curve. Derived from the same
    /// token so the two cannot drift apart.
    public var travelSpring: Spring

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
                snap: flat, glide: flat, pop: flat, drift: flat, travel: flat,
                float: flat, tint: flat, bounce: flat,
                arrivalTilt: 0,
                staggerDelay: 0,
                travelSpring: Spring(duration: 0.10 * s, bounce: 0)
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
            travel: .spring(duration: 0.46 * s, bounce: 0.26),
            float: .spring(duration: 0.85 * s, bounce: 0.10),
            tint: .easeOut(duration: 0.15 * s),
            // A spring at a damping ratio of about 0.58 — one clear overshoot
            // and done. Past the 0.34 the rest of the system tops out at,
            // because the things this carries are small: the same bounce that
            // reads as unstable on a panel reads as spirited on a bubble.
            bounce: .spring(duration: 0.36 * s, bounce: 0.42),
            arrivalTilt: 2.5,
            staggerDelay: 0.035 * s,
            travelSpring: Spring(duration: 0.46 * s, bounce: 0.26)
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
