import SwiftUI

// MARK: - Phase

/// What a petal is currently doing. Deliberately coarser than the menu's own phase:
/// "opening" and "open" map to the same petal phase so that finishing an expansion
/// does not restart the petal's keyframe timeline.
enum PetalMotionPhase: Hashable, Sendable {
    case opening
    case closing
    case blowingUp
    case shrinking
}

// MARK: - Animated value

/// The single value a petal's `KeyframeAnimator` drives.
///
/// Position is *derived* from `progress` rather than animated directly. Core
/// Animation applied the group's ease-in curve to the timeline and then sampled the
/// path at the eased progress; driving one eased progress track and sampling the
/// polyline reproduces that composition exactly, where easing each segment
/// separately would not. It is also less work per frame than three tracks.
struct PetalPose: Equatable {
    var progress: Double = 0
    var scale: Double = 1
    var opacity: Double = 1
}

// MARK: - Rotation

/// The petal's spin, expressed as a function of progress so it stays locked to the
/// travel no matter which curve is driving it.
enum PetalRotation: Equatable, Sendable {
    case none
    /// Held at `degrees` until 30% and unwound to zero by 40%, as in the original's
    /// `[π, 0]` keyframes at keyTimes `[0.3, 0.4]`.
    case expanding(degrees: Double)
    /// Zero to `degrees` by 40%, back to zero by 50%, as in the original's
    /// `[0, 2π, 0]` at keyTimes `[0, 0.4, 0.5]`.
    case closing(degrees: Double)

    func degrees(at progress: Double) -> Double {
        switch self {
        case .none:
            return 0

        case let .expanding(degrees):
            if progress <= 0.3 { return degrees }
            if progress >= 0.4 { return 0 }
            return degrees * (1 - (progress - 0.3) / 0.1)

        case let .closing(degrees):
            if progress <= 0 { return 0 }
            if progress <= 0.4 { return degrees * (progress / 0.4) }
            if progress <= 0.5 { return degrees * (1 - (progress - 0.4) / 0.1) }
            return 0
        }
    }
}

// MARK: - Timeline

/// Everything a petal needs for one transition, resolved up front so that nothing
/// is derived inside the per-frame closure.
struct PetalTimeline: Equatable {
    var path: PetalPath
    var rotation: PetalRotation
    var delay: Double
    var duration: Double
    var startProgress: Double = 0
    var endProgress: Double = 1
    var startScale: Double = 1
    var endScale: Double = 1
    var startOpacity: Double = 1
    var endOpacity: Double = 1
    var spring: PetalSpring?

    var initialPose: PetalPose {
        PetalPose(progress: startProgress, scale: startScale, opacity: startOpacity)
    }

    /// Whether scale or opacity actually move during this phase. They only do so on
    /// selection; during travel both are pinned at 1. Applying `scaleEffect` and
    /// `opacity` regardless costs nothing visually but forces a live glass layer
    /// through an offscreen composite on every frame, so the modifiers are omitted
    /// entirely when the tracks are flat.
    var animatesEmphasis: Bool {
        startScale != endScale || startOpacity != endOpacity
    }

    var animatesRotation: Bool { rotation != .none }

    static func make(
        phase: PetalMotionPhase,
        anchors: PathMenuAnchors,
        index: Int,
        count: Int,
        style: PathMenuStyle,
        reduceMotion: Bool
    ) -> PetalTimeline {
        // Reduce Motion keeps the petal at its resting position and cross-fades.
        if reduceMotion {
            switch phase {
            case .opening:
                return PetalTimeline(
                    path: PetalPath(anchors.end), rotation: .none,
                    delay: 0, duration: 0.2,
                    startScale: 0.86, endScale: 1,
                    startOpacity: 0, endOpacity: 1
                )
            case .closing:
                return PetalTimeline(
                    path: PetalPath(anchors.end), rotation: .none,
                    delay: 0, duration: 0.2,
                    startScale: 1, endScale: 0.86,
                    startOpacity: 1, endOpacity: 0
                )
            case .blowingUp, .shrinking:
                return PetalTimeline(
                    path: PetalPath(anchors.end), rotation: .none,
                    delay: 0, duration: 0.2,
                    startOpacity: 1, endOpacity: 0
                )
            }
        }

        let spring = style.motion.springParameters.map {
            PetalSpring(response: $0.response, dampingRatio: $0.dampingRatio)
        }

        switch phase {
        case .opening:
            // start → far → near → end, exactly as the original's CGPath.
            let path = spring == nil
                ? PetalPath(.zero, anchors.far, anchors.near, anchors.end)
                : PetalPath(.zero, anchors.end)
            return PetalTimeline(
                path: path,
                rotation: style.rotatesPetals
                    ? .expanding(degrees: style.expandRotation.degrees)
                    : .none,
                delay: Double(index) * style.stagger,
                duration: style.duration,
                spring: spring
            )

        case .closing:
            // end → far → start.
            let path = spring == nil
                ? PetalPath(anchors.end, anchors.far, .zero)
                : PetalPath(anchors.end, .zero)
            return PetalTimeline(
                path: path,
                rotation: style.rotatesPetals
                    ? .closing(degrees: style.closeRotation.degrees)
                    : .none,
                // Petals return in reverse order, as the original's timer counted down.
                delay: Double(count - 1 - index) * style.stagger,
                duration: style.duration,
                spring: spring
            )

        case .blowingUp:
            return PetalTimeline(
                path: PetalPath(anchors.end), rotation: .none,
                delay: 0, duration: style.duration,
                startScale: 1, endScale: 3,
                startOpacity: 1, endOpacity: 0
            )

        case .shrinking:
            return PetalTimeline(
                path: PetalPath(anchors.end), rotation: .none,
                delay: 0, duration: style.duration,
                startScale: 1, endScale: 0.01,
                startOpacity: 1, endOpacity: 0
            )
        }
    }
}

/// Spring parameters, kept as an `Equatable` value so `PetalTimeline` can be too.
struct PetalSpring: Equatable, Sendable {
    var response: Double
    var dampingRatio: Double
}

// MARK: - Petal

/// One item of the menu, animating itself.
///
/// The menu never drives this per frame. It hands over a phase, and the petal runs
/// its own timeline — so a frame of animation touches only this subtree, and only
/// its draw-time modifiers (`offset`, `rotationEffect`, `scaleEffect`, `opacity`),
/// none of which invalidate layout.
struct PathMenuPetal<Content: View>: View {

    let content: Content
    let anchors: PathMenuAnchors
    let index: Int
    let count: Int
    let style: PathMenuStyle
    let phase: PetalMotionPhase
    let reduceMotion: Bool
    let isInteractive: Bool
    /// Progress supplied by the menu instead of run here.
    ///
    /// `nil` — every surface but the gooey one — leaves the petal animating
    /// itself, which is cheaper and touches nothing outside this subtree. The
    /// gooey surface needs every petal's position at once to build one merged
    /// silhouette from them, so there it runs a single timeline at the container
    /// and hands each petal its share of it.
    var externalProgress: Double?
    let onTap: () -> Void
    let onHover: (Bool) -> Void

    /// `KeyframeAnimator` plays its timeline when the trigger *changes*, not when it
    /// first appears — and a petal is mounted at the same moment it is told to open.
    /// Arming the trigger one step after mount gives it that change, and the frame
    /// spent at the initial pose is invisible because the petal starts underneath
    /// the button.
    @State private var armedPhase: PetalMotionPhase?

    var body: some View {
        // Resolved once per phase change and captured by the closures below, so the
        // per-frame path never recomputes it.
        let timeline = PetalTimeline.make(
            phase: phase,
            anchors: anchors,
            index: index,
            count: count,
            style: style,
            reduceMotion: reduceMotion
        )
        // A zero-duration keyframe is not meaningful; the stagger hold needs some
        // width even for the first petal.
        let hold = max(timeline.delay, 1e-4)

        Group {
            if let externalProgress {
                driven(by: externalProgress, timeline)
            } else {
                selfAnimating(timeline, hold: hold)
            }
        }
        // Keeps the petal's animating geometry from propagating into the container.
        .geometryGroup()
        .onAppear { armedPhase = phase }
        .onChange(of: phase) { _, newPhase in armedPhase = newPhase }
        .allowsHitTesting(isInteractive)
        // These branches are constant for the duration of a phase, and the phase and
        // the animator's trigger change together, so no identity churn mid-flight.
        .accessibilityHidden(!isInteractive)
        .onTapGesture(perform: onTap)
        .onHover { hovering in onHover(isInteractive && hovering) }
    }

    /// The petal running its own timeline. Every surface but the gooey one.
    private func selfAnimating(_ timeline: PetalTimeline, hold: Double) -> some View {
        KeyframeAnimator(initialValue: timeline.initialPose, trigger: armedPhase) { pose in
            // Order matters: scale and opacity must be applied before the offset, or
            // scaling would scale the translation and move the petal.
            emphasised(pose, timeline)
                .offset(timeline.path.point(at: pose.progress))
        } keyframes: { _ in
            KeyframeTrack(\.progress) {
                LinearKeyframe(timeline.startProgress, duration: hold)
                if let spring = timeline.spring {
                    SpringKeyframe(
                        timeline.endProgress,
                        duration: timeline.duration,
                        spring: Spring(response: spring.response, dampingRatio: spring.dampingRatio)
                    )
                } else {
                    LinearKeyframe(
                        timeline.endProgress,
                        duration: timeline.duration,
                        timingCurve: .easeIn
                    )
                }
            }
            KeyframeTrack(\.scale) {
                LinearKeyframe(timeline.startScale, duration: hold)
                LinearKeyframe(timeline.endScale, duration: timeline.duration, timingCurve: .easeOut)
            }
            KeyframeTrack(\.opacity) {
                LinearKeyframe(timeline.startOpacity, duration: hold)
                LinearKeyframe(timeline.endOpacity, duration: timeline.duration, timingCurve: .easeOut)
            }
        }
    }

    /// The petal placed where the menu says it is.
    ///
    /// Same path, same sampler, same order of modifiers — only the source of
    /// `progress` differs, which is what keeps the two paths landing on
    /// identical geometry.
    private func driven(by progress: Double, _ timeline: PetalTimeline) -> some View {
        let pose = PetalPose(
            progress: progress,
            scale: timeline.startScale + (timeline.endScale - timeline.startScale) * progress,
            opacity: timeline.startOpacity + (timeline.endOpacity - timeline.startOpacity) * progress
        )
        return emphasised(pose, timeline)
            .offset(timeline.path.point(at: progress))
    }

    @ViewBuilder
    private func emphasised(_ pose: PetalPose, _ timeline: PetalTimeline) -> some View {
        if timeline.animatesEmphasis {
            rotated(pose, timeline)
                .scaleEffect(pose.scale)
                .opacity(pose.opacity)
        } else {
            rotated(pose, timeline)
        }
    }

    @ViewBuilder
    private func rotated(_ pose: PetalPose, _ timeline: PetalTimeline) -> some View {
        if timeline.animatesRotation {
            content.rotationEffect(.degrees(timeline.rotation.degrees(at: pose.progress)))
        } else {
            content
        }
    }
}
