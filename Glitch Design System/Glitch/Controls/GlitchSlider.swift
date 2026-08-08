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
    /// pulls it in. Roughly 3.5% — near enough that landing on a round number
    /// feels like aim rather than luck, far enough that it doesn't fight you.
    public static let pullTolerance: Double = 0.035

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
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .glitchHover(onHoverChange)
            .glitchScrollWheel(isActive: isHovering && isEnabled && !isEditing) { delta in
                adjust(by: Double(delta) * effectiveStep * 0.25)
            }
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

        return shape
            .fill(palette.track)
            .overlay {
                // Styles that draw their edges outline the track; the default
                // one separates surfaces by tone alone.
                shape.strokeBorder(
                    metrics.tracksAreOutlined ? palette.stroke : .clear,
                    lineWidth: metrics.borderWidth
                )
            }
            .overlay(alignment: .leading) { hashmarks }
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(isActive ? palette.fillActive : palette.fill)
                    .frame(width: fillWidth)
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
    /// is coarse, otherwise every 10%. Invisible until the row is engaged —
    /// they are guidance for the gesture in progress, not decoration.
    private var hashmarks: some View {
        GeometryReader { proxy in
            ForEach(Array(tickFractions.enumerated()), id: \.offset) { _, fraction in
                RoundedRectangle(
                    cornerRadius: theme.metrics.partRadius(theme.metrics.hashmarkWidth)
                )
                    .fill(theme.palette.hashmark.opacity(isActive ? 1 : 0))
                    .frame(width: theme.metrics.hashmarkWidth, height: theme.metrics.hashmarkHeight)
                    .position(
                        x: proxy.size.width * fraction,
                        y: proxy.size.height / 2
                    )
            }
        }
        .animation(motion.tint, value: isActive)
        .allowsHitTesting(false)
    }

    private var handle: some View {
        RoundedRectangle(cornerRadius: theme.metrics.partRadius(theme.metrics.handleWidth))
            .fill(theme.palette.handle)
            .frame(width: theme.metrics.handleWidth, height: theme.metrics.handleHeight)
            // Retracted to a quarter width at rest and grown on engagement, so
            // the row reads as a bar until you touch it and as a slider the
            // moment you do.
            .scaleEffect(
                x: isActive ? 1 : 0.25,
                y: (isActive && handleCollidesWithText) ? 0.75 : 1,
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

    private var isActive: Bool { (isHovering || isPressed) && isEnabled }

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
        guard isActive else { return 0 }
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

    // MARK: - Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                guard isEnabled, !isEditing else { return }

                if !isPressed {
                    isPressed = true
                    isFocused = true
                    cancelEditOffer()
                }

                let travel = hypot(
                    gesture.location.x - gesture.startLocation.x,
                    gesture.location.y - gesture.startLocation.y
                )
                if !isDragging, travel > dragThreshold {
                    isDragging = true
                }
                guard isDragging else { return }

                // Motion rule 7: while the pointer is down the fill tracks it
                // exactly, with no spring in between.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    overscroll = overscrollOffset(forX: gesture.location.x)
                    commit(valueAt(gesture.location.x))
                }
            }
            .onEnded { gesture in
                guard isEnabled else { return }

                if !isDragging {
                    // A click: help it onto a tick, and animate there.
                    let raw = rawValue(at: gesture.location.x)
                    let target = notchSnapping == .locked
                        ? GlitchValueMath.nearestNotch(to: raw, in: range, step: step)
                        : GlitchValueMath.snapToClick(raw, in: range, step: step)
                    if target != value {
                        withAnimation(motion.glide) { value = target }
                        GlitchHaptics.selection()
                    }
                }

                if overscroll != 0 {
                    withAnimation(motion.drift) { overscroll = 0 }
                }
                isPressed = false
                isDragging = false
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

    private func valueAt(_ x: CGFloat) -> Double {
        let raw = rawValue(at: x)

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
        let wasAtLimit = value == range.lowerBound || value == range.upperBound
        let isAtLimit = next == range.lowerBound || next == range.upperBound

        value = next

        if isAtLimit && !wasAtLimit {
            GlitchHaptics.limit()
        } else {
            GlitchHaptics.tick()
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
        withAnimation(motion.glide) { value = next }
        GlitchHaptics.tick()
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
        if next != value {
            withAnimation(motion.glide) { value = next }
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
