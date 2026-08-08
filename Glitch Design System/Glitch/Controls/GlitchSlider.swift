import SwiftUI

/// Whether dragging a slider sticks to its notches.
///
/// The notches are the drawn hashmarks, so whatever a slider snaps to is
/// something you can see. Which mode is right depends on what the value is
/// for: a percentage people set to round numbers wants magnetism, a physical
/// dimension being matched to something else wants none.
public enum GlitchNotchSnapping: String, CaseIterable, Sendable, Hashable {
    /// Free movement — the value quantises to `step` and nothing else.
    /// The reference panel's behaviour.
    case off
    /// Notches attract, but only from close by. Round numbers become easy to
    /// hit while every value in between stays reachable.
    case magnetic
    /// Every drag lands on a notch. Use when the in-between values are not
    /// meaningful.
    case locked

    /// How close a value must come, as a fraction of the range, before a notch
    /// pulls it in.
    ///
    /// Two percent. Wide enough to catch a value you were aiming at, narrow
    /// enough that it never takes one you set deliberately in between —
    /// magnetism you can feel but never fight.
    ///
    /// The notch lights up from further out than this (see
    /// `GlitchDelightTuning.notchProximity`), so the pull is always announced
    /// before it happens.
    public static let pullTolerance: Double = 0.02

    public var title: String {
        switch self {
        case .off: "Off"
        case .magnetic: "Magnetic"
        case .locked: "Locked"
        }
    }
}

/// The system's signature control: label, fill and value in a single row.
///
/// Behaviour follows the reference panel exactly, and three of its decisions
/// are worth stating because they are easy to "fix" into something worse:
///
/// - **Pressing does not move the value.** Touch-down only wakes the row up.
///   A slider that jumps on press cannot be clicked to focus, cannot be
///   pressed and reconsidered, and turns every mis-aimed click into an edit.
///   Movement past a 3pt threshold is what starts a drag.
/// - **A click and a drag are different gestures.** A drag is a continuous
///   statement of intent and is taken literally, with no animation between the
///   pointer and the fill. A click is one guess at a position, so it is helped
///   onto a nearby tick and *animates* there — there is no finger for it to
///   lag behind.
/// - **The track itself stretches past its limits.** Not the contents sliding
///   within it: the whole row grows, which is why the resistance reads as the
///   control straining rather than as its label drifting.
public struct GlitchSlider: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.glitchDelight) private var delight
    @Environment(\.isEnabled) private var isEnabled

    private let label: String
    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let step: Double
    private let decimalsOverride: Int?
    private let notchSnapping: GlitchNotchSnapping

    /// Movement beyond this many points turns a press into a drag.
    private let dragThreshold: CGFloat = 3
    /// How long the pointer must rest on the row before the value offers to be
    /// typed. Long enough that it never appears while passing over.
    private let editRevealDelay: Duration = .milliseconds(800)

    @State private var isHovering = false
    @State private var isPressed = false
    @State private var isDragging = false
    @State private var trackWidth: CGFloat = 0
    @State private var labelWidth: CGFloat = 0
    @State private var valueWidth: CGFloat = 0
    @State private var overscroll: CGFloat = 0
    @State private var offersEditing = false
    @State private var isEditing = false
    @State private var draft = ""
    @State private var revealTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool
    @FocusState private var isFieldFocused: Bool

    // Game-feel layer. All of it inert when `delight` is off.
    @State private var fillTrail: CGFloat = 0
    @State private var anticipation: CGFloat = 0
    @State private var handleSquash: CGFloat = 1
    @State private var shake: CGFloat = 0
    @State private var ghostFraction: Double?
    @State private var ghostOpacity: Double = 0
    @State private var ghostTask: Task<Void, Never>?
    @State private var jumpTask: Task<Void, Never>?
    /// While set, the value is held still: the drag keeps happening, but the
    /// control refuses to move until the moment passes.
    @State private var hitStopUntil: ContinuousClock.Instant?

    // Forgiveness. The exact instant a finger lifts or lands is a noisy signal
    // of what someone meant; these remember just enough to read through it.
    @State private var lastReleaseAt: ContinuousClock.Instant?
    @State private var lastReleaseX: CGFloat = 0
    @State private var lastClickAt: ContinuousClock.Instant?
    @State private var isFineDrag = false
    /// Once a drag has changed gear, position is measured from where the
    /// change happened rather than from the track's origin — otherwise
    /// returning to coarse would teleport the value to the pointer.
    @State private var usesRelativeTracking = false
    @State private var relativeAnchorX: CGFloat = 0
    @State private var relativeAnchorValue: Double = 0

    public init(
        _ label: String,
        value: Binding<Double>,
        in range: ClosedRange<Double> = 0...100,
        step: Double = 1,
        decimals: Int? = nil,
        notches: GlitchNotchSnapping = .off
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.step = step
        self.decimalsOverride = decimals
        self.notchSnapping = notches
    }

    public var body: some View {
        Color.clear
            .frame(height: theme.metrics.rowHeight)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { trackWidth = $0 }
            // Drawn as an overlay so the stretch at the limits changes what is
            // painted without disturbing the row's layout.
            .overlay(alignment: .leading) {
                track
                    .frame(width: stretchedWidth, height: theme.metrics.rowHeight)
                    .offset(x: min(0, overscroll))
            }
            .offset(x: shake)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .glitchHover(onHoverChange)
            .focusable(isEnabled)
            .focused($isFocused)
            .glitchFocusRing(isFocused: isFocused, radius: theme.metrics.controlRadius)
            .onKeyPress(keys: [.leftArrow, .rightArrow]) { press in
                guard isEnabled else { return .ignored }
                let magnitude = effectiveStep * (press.modifiers.contains(.shift) ? 10 : 1)
                adjust(by: press.key == .leftArrow ? -magnitude : magnitude)
                return .handled
            }
            .onDisappear { revealTask?.cancel() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(formattedValue)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: adjust(by: effectiveStep)
                case .decrement: adjust(by: -effectiveStep)
                @unknown default: break
                }
            }
    }

    // MARK: - Track

    private var track: some View {
        let metrics = theme.metrics
        let palette = theme.palette
        let shape = RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous)

        return Color.clear
            .glitchSurface(shape, fill: palette.track)
            .overlay {
                // Styles that draw their edges outline the track; the default
                // one separates surfaces by tone alone.
                shape.strokeBorder(
                    metrics.tracksAreOutlined ? palette.stroke : .clear,
                    lineWidth: metrics.borderWidth
                )
            }
            .overlay(alignment: .leading) { hashmarks }
            .overlay(alignment: .leading) { ghost }
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(isActive ? palette.fillActive : palette.fill)
                    // Inertia, not latency: the fill lags a fast drag by a
                    // couple of points and catches up as it slows. Same idea
                    // as a camera trailing a sprinting character.
                    //
                    // `anticipation` is the opposite move: a brief pull-back
                    // before a jump, so the value looks like it gathers itself
                    // rather than teleporting.
                    .frame(width: max(0, fillWidth + fillTrail + anticipation))
                    .animation(motion.tint, value: isActive)
            }
            .overlay(alignment: .leading) { handle }
            .overlay(alignment: .leading) {
                GlitchType.labelText(label, theme)
                    .foregroundStyle(palette.label)
                    .lineLimit(1)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { labelWidth = $0 }
                    .padding(.leading, metrics.labelInset)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .trailing) {
                readout.padding(.trailing, metrics.labelInset)
            }
            .clipShape(shape)
            .opacity(isEnabled ? 1 : 0.4)
    }

    /// Ticks the click-snapping actually lands on: one per step when the range
    /// is coarse, otherwise every 10%.
    ///
    /// Hidden until the row is engaged, unless the style prints its scale onto
    /// the chassis. The nearest one brightens and grows as the value
    /// approaches, so a notch announces itself *before* it pulls — the same
    /// courtesy a magnet that only ever grabbed silently would not extend.
    private var hashmarks: some View {
        let metrics = theme.metrics
        let approaching = approachingNotch

        // Kept inside the row: the tallest a notch may grow is the row itself,
        // whatever height the style gave it at rest.
        let maxGrowthY = max(1, (metrics.rowHeight - 4) / max(1, metrics.hashmarkHeight))

        return GeometryReader { proxy in
            ForEach(Array(tickFractions.enumerated()), id: \.offset) { _, tick in
                let strength = CGFloat(
                    approaching.flatMap { abs($0.fraction - Double(tick)) < 1e-9 ? $0.strength : nil } ?? 0
                )
                let visible = isActive || metrics.hashmarksAlwaysVisible

                ZStack {
                    RoundedRectangle(cornerRadius: metrics.partRadius(metrics.hashmarkWidth))
                        .fill(theme.palette.hashmark)
                    // The approaching notch takes on the handle's own colour,
                    // so it reads as the thing about to catch the value rather
                    // than as a brighter tick.
                    RoundedRectangle(cornerRadius: metrics.partRadius(metrics.hashmarkWidth))
                        .fill(theme.palette.handle)
                        .opacity(Double(strength) * GlitchDelightTuning.notchHighlightOpacity)
                }
                .frame(width: metrics.hashmarkWidth, height: metrics.hashmarkHeight)
                .scaleEffect(
                    x: 1 + GlitchDelightTuning.notchGrowthX * strength,
                    y: min(maxGrowthY, 1 + GlitchDelightTuning.notchGrowthY * strength)
                )
                .opacity(visible ? 1 : 0)
                .position(x: proxy.size.width * tick, y: proxy.size.height / 2)
                .animation(motion.pop, value: strength)
            }
        }
        .animation(motion.tint, value: isActive)
        .allowsHitTesting(false)
    }

    /// A fading trace of where the value was before it jumped, so a click
    /// shows its distance travelled rather than only its destination.
    @ViewBuilder
    private var ghost: some View {
        if let ghostFraction {
            Rectangle()
                .fill(theme.palette.fill)
                .frame(width: stretchedWidth * CGFloat(ghostFraction))
                .opacity(ghostOpacity)
                .allowsHitTesting(false)
        }
    }

    private var handle: some View {
        let metrics = theme.metrics
        // Retracted to a quarter width at rest, so the row reads as a bar
        // until you touch it and as a slider the moment you do — unless the
        // style keeps its handle permanently visible, in which case shrinking
        // it would just make it look broken.
        let restingScaleX: CGFloat = metrics.handleAlwaysVisible ? 1 : 0.25

        return RoundedRectangle(cornerRadius: metrics.partRadius(metrics.handleWidth))
        .fill(theme.palette.handle)
        .frame(width: metrics.handleWidth, height: metrics.handleHeight)
        // Squash and stretch: the handle compresses along its travel and
        // swells across it as a value lands. One technique, more liveliness
        // than any other for the cost.
        .scaleEffect(
            x: (isActive ? 1 : restingScaleX) * (2 - handleSquash),
            y: ((isActive && handleCollidesWithText) ? 0.75 : 1) * handleSquash,
            anchor: .center
        )
        .opacity(handleOpacity)
        .offset(x: handleX)
        .animation(motion.pop, value: isActive)
        .animation(motion.tint, value: handleOpacity)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var readout: some View {
        if isEditing {
            TextField("", text: $draft)
                .textFieldStyle(.plain)
                .focusEffectDisabled()
                .font(GlitchType.value(theme))
                .foregroundStyle(theme.palette.textPrimary)
                .multilineTextAlignment(.trailing)
                .frame(width: 56)
                .focused($isFieldFocused)
                .onSubmit(commitDraft)
                .onKeyPress(.escape) {
                    endEditing()
                    return .handled
                }
                .onChange(of: isFieldFocused) { _, focused in
                    if !focused && isEditing { commitDraft() }
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(theme.palette.label)
                        .frame(height: 1)
                        .offset(y: 2)
                }
        } else {
            Text(formattedValue)
                .font(GlitchType.value(theme))
                .foregroundStyle(isActive ? theme.palette.textPrimary : theme.palette.label)
                .lineLimit(1)
                // Digits roll, in the direction the value moved — but never
                // under a finger, where rolling digits would lag the drag for
                // exactly the reason rule 7 forbids springing the fill.
                //
                // The animation is bound to `value` here rather than left to
                // the caller's `withAnimation`: a content transition needs an
                // animation on the update that changes the text, and an
                // ambient one does not reliably reach a Text this deep inside
                // overlays and geometry readers.
                .contentTransition(.numericText(value: value))
                .animation(isDragging ? nil : motion.glide, value: value)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { valueWidth = $0 }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(offersEditing ? theme.palette.label : .clear)
                        .frame(height: 1)
                        .offset(y: 2)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if offersEditing { beginEditing() }
                }
                .animation(motion.tint, value: offersEditing)
                .animation(motion.tint, value: isActive)
        }
    }

    // MARK: - Derived geometry

    /// Focus counts as active, so tabbing to a slider reveals its notches and
    /// handle exactly as pointing at it does. It is the only focus indicator
    /// the system has.
    private var isActive: Bool { (isHovering || isPressed || isFocused) && isEnabled }

    private var decimals: Int {
        decimalsOverride ?? GlitchNumberParsing.decimals(forStep: step)
    }

    private var formattedValue: String {
        GlitchNumberParsing.format(value, decimals: decimals)
    }

    private var fraction: CGFloat {
        CGFloat(GlitchValueMath.normalize(value, in: range))
    }

    private var stretchedWidth: CGFloat {
        max(0, trackWidth + abs(overscroll))
    }

    private var fillWidth: CGFloat {
        stretchedWidth * fraction
    }

    /// The handle rides just inside the fill's leading edge rather than
    /// straddling it, and never leaves the track.
    private var handleX: CGFloat {
        max(5, fillWidth - theme.metrics.handleInset)
    }

    /// True when the handle would sit on top of the label or the value.
    /// It fades almost away rather than crossing them, because a 3pt bar
    /// through the middle of a word is worse than no handle at all.
    private var handleCollidesWithText: Bool {
        guard stretchedWidth > 0 else { return false }
        let gap: CGFloat = 8
        let labelEdge = theme.metrics.labelInset + labelWidth + gap
        let valueEdge = stretchedWidth - theme.metrics.labelInset - valueWidth - gap
        return fillWidth < labelEdge || fillWidth > valueEdge
    }

    private var handleOpacity: Double {
        guard isActive else { return theme.metrics.handleAlwaysVisible ? 1 : 0 }
        if handleCollidesWithText { return 0.1 }
        return isDragging ? 0.9 : 0.5
    }

    private var effectiveStep: Double {
        step > 0 ? step : (range.upperBound - range.lowerBound) / 100
    }

    /// Drawn from the same list the snapping uses, so a notch you can see is
    /// always a notch you can land on.
    private var tickFractions: [CGFloat] {
        GlitchValueMath.notchFractions(in: range, step: step).map { CGFloat($0) }
    }

    /// The notch the value is closing in on, and how close it has got.
    ///
    /// `strength` runs 0 → 1 across the approach so the notch can grow
    /// continuously rather than snapping between two states. A binary
    /// highlight tells you a notch is near; a continuous one tells you *how*
    /// near, which is the whole point of foreshadowing.
    ///
    /// Nil when the slider doesn't snap — advertising a pull that will never
    /// come would be a lie.
    private var approachingNotch: (fraction: Double, strength: Double)? {
        guard delight, isActive, notchSnapping != .off else { return nil }

        let here = Double(fraction)
        let nearest = GlitchValueMath.notchFractions(in: range, step: step)
            .min { abs($0 - here) < abs($1 - here) }

        guard let nearest else { return nil }
        let distance = abs(nearest - here)
        guard distance <= GlitchDelightTuning.notchProximity else { return nil }

        let linear = 1 - distance / GlitchDelightTuning.notchProximity
        return (nearest, pow(linear, GlitchDelightTuning.notchApproachCurve))
    }

    // MARK: - Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                guard isEnabled, !isEditing else { return }

                if !isPressed {
                    isPressed = true
                    isFocused = true
                    cancelEditOffer()

                    // Release-latch. A finger that lifted a moment ago, right
                    // about here, was almost certainly still mid-adjustment —
                    // a bump, a repositioned grip, a trackpad that lost
                    // contact. Resuming the drag beats treating it as a fresh
                    // click, which would snap the value somewhere it was
                    // never asked to go.
                    if resumesPreviousDrag(at: gesture.location.x) {
                        isDragging = true
                    }
                }

                let travel = hypot(
                    gesture.location.x - gesture.startLocation.x,
                    gesture.location.y - gesture.startLocation.y
                )
                if !isDragging, travel > dragThreshold {
                    isDragging = true
                }
                guard isDragging else { return }

                // Hit-stop: having just arrived at a limit, the control holds
                // still for a few frames. The drag carries on around it.
                if let until = hitStopUntil {
                    guard ContinuousClock.now >= until else { return }
                    hitStopUntil = nil
                }

                // Motion rule 7: while the pointer is down the fill tracks it
                // exactly, with no spring in between.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    overscroll = overscrollOffset(forX: gesture.location.x)
                    fillTrail = trail(forVelocity: gesture.velocity.width)
                    updateFineMode(for: gesture)
                    commit(valueAt(gesture.location.x))
                }
            }
            .onEnded { gesture in
                guard isEnabled else { return }

                if isDragging {
                    landValue()
                } else {
                    // Intent buffering: a second click in quick succession
                    // means "let me type this", without the 800ms wait that is
                    // otherwise the only way to discover the editor.
                    if let previous = lastClickAt,
                       ContinuousClock.now - previous <= GlitchDelightTuning.doubleClickWindow,
                       delight {
                        lastClickAt = nil
                        beginEditing()
                    } else {
                        lastClickAt = ContinuousClock.now
                        jumpToClick(at: gesture.location.x)
                    }
                }

                if overscroll != 0 {
                    withAnimation(motion.drift) { overscroll = 0 }
                }
                if fillTrail != 0 {
                    withAnimation(motion.pop) { fillTrail = 0 }
                }
                lastReleaseAt = ContinuousClock.now
                lastReleaseX = gesture.location.x
                isPressed = false
                isDragging = false
                isFineDrag = false
                usesRelativeTracking = false
                hitStopUntil = nil
            }
    }

    /// A click, wound up and then released.
    ///
    /// The fill pulls back a couple of points before travelling — anticipation,
    /// which is what makes the movement look intended rather than teleported.
    private func jumpToClick(at x: CGFloat) {
        let raw = rawValue(at: x)
        let target = notchSnapping == .locked
            ? GlitchValueMath.nearestNotch(to: raw, in: range, step: step)
            : GlitchValueMath.snapToClick(raw, in: range, step: step)
        guard target != value else { return }

        let forward = target > value
        leaveGhost()

        guard delight else {
            withAnimation(motion.glide) { value = target }
            GlitchHaptics.selection()
            return
        }

        jumpTask?.cancel()
        anticipation = forward ? -GlitchDelightTuning.anticipation : GlitchDelightTuning.anticipation

        jumpTask = Task { @MainActor in
            try? await Task.sleep(for: GlitchDelightTuning.anticipationHold)
            guard !Task.isCancelled else { return }
            withAnimation(motion.glide) {
                anticipation = 0
                value = target
            }
            GlitchHaptics.selection()
            GlitchSound.commit()
            landValue()
        }
    }

    /// The squash a value makes on arriving.
    private func landValue() {
        guard delight else { return }
        withAnimation(motion.snap) { handleSquash = GlitchDelightTuning.landingSquash }
        withAnimation(motion.pop.delay(0.06)) { handleSquash = 1 }
    }

    /// A short lateral kick, for the one case where the user is definitely
    /// wrong and would otherwise be told nothing: a typed value out of range.
    private func rejectValue() {
        GlitchHaptics.limit()
        GlitchSound.reject()

        guard delight else { return }
        withAnimation(motion.snap) { shake = GlitchDelightTuning.rejectionKick }
        withAnimation(motion.pop.delay(0.07)) { shake = -GlitchDelightTuning.rejectionKick * 0.6 }
        withAnimation(motion.drift.delay(0.15)) { shake = 0 }
    }

    /// Whether this press continues the drag that just ended.
    private func resumesPreviousDrag(at x: CGFloat) -> Bool {
        guard delight, let released = lastReleaseAt else { return false }
        guard ContinuousClock.now - released <= GlitchDelightTuning.releaseLatch else { return false }
        return abs(x - lastReleaseX) <= GlitchDelightTuning.releaseLatchDistance
    }

    /// Fine adjustment engages only on a deliberate, mostly-vertical excursion,
    /// and disengages later than it engages.
    ///
    /// Without the hysteresis a hand that wobbles across the boundary changes
    /// gear repeatedly mid-drag, which feels like the control malfunctioning.
    private func updateFineMode(for gesture: DragGesture.Value) {
        guard delight else { return }
        let vertical = abs(gesture.translation.height)
        let horizontal = abs(gesture.translation.width)
        let threshold = theme.metrics.rowHeight * 1.5

        let wasFine = isFineDrag
        if isFineDrag {
            isFineDrag = vertical > threshold * GlitchDelightTuning.fineExitRatio
        } else {
            isFineDrag = vertical > threshold && vertical > horizontal
        }

        if isFineDrag != wasFine {
            // Re-anchor on every gear change, in both directions.
            usesRelativeTracking = true
            relativeAnchorX = gesture.location.x
            relativeAnchorValue = value
        }
    }

    /// Inertia proportional to drag speed, capped well below the point where
    /// it would read as the control failing to keep up.
    private func trail(forVelocity velocity: CGFloat) -> CGFloat {
        guard delight else { return 0 }
        let normalized = velocity / GlitchDelightTuning.trailReferenceVelocity
        let clamped = min(max(normalized, -1), 1)
        return -clamped * GlitchDelightTuning.maxFillTrail
    }

    /// Leaves the current fill behind as a fading trace before the value moves.
    private func leaveGhost() {
        guard delight else { return }

        ghostTask?.cancel()
        ghostFraction = Double(fraction)
        ghostOpacity = GlitchDelightTuning.ghostOpacity
        withAnimation(motion.drift) { ghostOpacity = 0 }

        ghostTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            ghostFraction = nil
        }
    }

    private func overscrollOffset(forX x: CGFloat) -> CGFloat {
        if x < 0 {
            return -CGFloat(GlitchValueMath.trackOverscroll(pastEdge: Double(-x)))
        }
        if x > trackWidth {
            return CGFloat(GlitchValueMath.trackOverscroll(pastEdge: Double(x - trackWidth)))
        }
        return 0
    }

    private func rawValue(at x: CGFloat) -> Double {
        guard trackWidth > 0 else { return range.lowerBound }
        let span = range.upperBound - range.lowerBound
        return range.lowerBound
            + GlitchValueMath.fraction(ofX: Double(x), width: Double(trackWidth)) * span
    }

    /// Movement measured from the last gear change, at whichever rate the
    /// current gear calls for.
    private func relativeValue(at x: CGFloat) -> Double {
        guard trackWidth > 0 else { return relativeAnchorValue }
        let span = range.upperBound - range.lowerBound
        let scale = isFineDrag ? GlitchDelightTuning.fineScale : 1
        let travelled = Double((x - relativeAnchorX) / trackWidth) * span * scale
        return GlitchValueMath.clamp(relativeAnchorValue + travelled, to: range)
    }

    private func valueAt(_ x: CGFloat) -> Double {
        let raw = usesRelativeTracking ? relativeValue(at: x) : rawValue(at: x)

        switch notchSnapping {
        case .off:
            return GlitchValueMath.snap(raw, step: step, in: range)

        case .magnetic:
            let notch = GlitchValueMath.nearestNotch(to: raw, in: range, step: step)
            let span = range.upperBound - range.lowerBound
            // A notch is returned as-is rather than re-quantised, because a
            // notch at 10% of the range is not necessarily a multiple of the
            // step, and rounding it again would push it back off.
            if span > 0, abs(notch - raw) / span <= GlitchNotchSnapping.pullTolerance {
                return notch
            }
            return GlitchValueMath.snap(raw, step: step, in: range)

        case .locked:
            return GlitchValueMath.nearestNotch(to: raw, in: range, step: step)
        }
    }

    private func commit(_ next: Double) {
        guard next != value else { return }
        let previous = value
        let wasAtLimit = value == range.lowerBound || value == range.upperBound
        let isAtLimit = next == range.lowerBound || next == range.upperBound

        value = next

        if isAtLimit && !wasAtLimit {
            GlitchHaptics.limit()
            // Arriving at a limit is an event, so give it a beat. Fighting
            // games freeze both fighters for a few frames on a connecting hit
            // for exactly this reason: without the pause the collision is
            // something you infer from the aftermath rather than something you
            // felt happen.
            if delight {
                hitStopUntil = ContinuousClock.now.advanced(by: GlitchDelightTuning.hitStop)
                GlitchSound.reject()
            }
        } else {
            GlitchHaptics.tick()
            if delight, crossedNotch(from: previous, to: next) {
                GlitchSound.tick()
            }
        }
    }

    /// Whether a change stepped over one of the drawn notches — the only
    /// crossings worth making a sound about, since a tick on every step of a
    /// 700-unit range would be a buzz.
    private func crossedNotch(from previous: Double, to next: Double) -> Bool {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return false }

        let low = min(previous, next)
        let high = max(previous, next)
        return GlitchValueMath.notchFractions(in: range, step: step).contains { fraction in
            let notch = range.lowerBound + fraction * span
            return notch > low && notch <= high
        }
    }

    /// Keyboard, scroll and VoiceOver — none of which the reference supports,
    /// and all of which animate, since no pointer is holding the value.
    private func adjust(by delta: Double) {
        guard isEnabled, !isEditing else { return }
        let next = GlitchValueMath.snap(value + delta, step: step, in: range)
        guard next != value else {
            GlitchHaptics.limit()
            return
        }
        leaveGhost()
        withAnimation(motion.glide) { value = next }
        GlitchHaptics.tick()
        if delight { GlitchSound.commit() }
        landValue()
    }

    // MARK: - Hover and editing

    private func onHoverChange(_ hovering: Bool) {
        withAnimation(motion.tint) { isHovering = hovering }

        revealTask?.cancel()
        guard hovering, isEnabled, !isEditing else {
            cancelEditOffer()
            return
        }
        revealTask = Task { @MainActor in
            try? await Task.sleep(for: editRevealDelay)
            guard !Task.isCancelled else { return }
            withAnimation(motion.tint) { offersEditing = true }
        }
    }

    private func cancelEditOffer() {
        revealTask?.cancel()
        revealTask = nil
        if offersEditing {
            withAnimation(motion.tint) { offersEditing = false }
        }
    }

    private func beginEditing() {
        draft = formattedValue
        isEditing = true
        isFieldFocused = true
    }

    private func commitDraft() {
        let parsed = GlitchNumberParsing.parse(draft, fallback: value)
        let next = GlitchValueMath.snap(parsed, step: step, in: range)

        // Typing 900 into a 0–100 slider is the one case where the user is
        // definitely wrong and, until now, was told nothing at all: the number
        // simply became 100 with no explanation.
        let wasOutOfRange = parsed < range.lowerBound || parsed > range.upperBound

        if next != value {
            withAnimation(motion.glide) { value = next }
        }
        if wasOutOfRange {
            rejectValue()
        } else if next != value {
            landValue()
        }
        endEditing()
    }

    private func endEditing() {
        isFieldFocused = false
        isEditing = false
        cancelEditOffer()
    }
}

#Preview("Slider") {
    @Previewable @State var glow = 0.03
    @Previewable @State var vignette = 0.5
    @Previewable @State var shadow = 0.57
    @Previewable @State var width = 464.0

    VStack(spacing: 6) {
        GlitchSlider("Glow", value: $glow, in: 0...0.2, step: 0.001)
        GlitchSlider("Vignette", value: $vignette, in: 0...1, step: 0.01)
        GlitchSlider("Ground Shadow", value: $shadow, in: 0...1, step: 0.01)
        GlitchSlider("Width", value: $width, in: 200...800, step: 1)
        GlitchSlider("Disabled", value: $vignette, in: 0...1, step: 0.01).disabled(true)
    }
    .padding(12)
    .frame(width: 280)
    .background(GlitchPalette.dark.panel)
    .glitchTheme()
    .preferredColorScheme(.dark)
}
