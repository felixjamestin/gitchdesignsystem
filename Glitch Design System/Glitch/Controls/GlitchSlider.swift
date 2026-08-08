import SwiftUI

/// The system's signature control: label, fill and value in a single row.
///
/// The idea is taken from both reference images — a slider that is also its own
/// label, so a panel of twelve parameters costs twelve rows rather than
/// twenty-four.
///
/// Interaction notes worth knowing before changing anything here:
///
/// - The whole track is the handle. Pressing anywhere jumps the value there and
///   grabs it, so there is no small knob to hunt for. This is the single
///   biggest feel difference from a stock slider.
/// - Nothing animates while the finger is down (motion rule 7). A spring
///   between the input and the fill reads as lag, however pretty it looks in
///   isolation.
/// - Pushing past either end meets resistance rather than a dead stop, so the
///   limit is felt instead of merely observed.
public struct GlitchSlider: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.isEnabled) private var isEnabled

    private let label: String
    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let step: Double
    private let defaultValue: Double?
    private let decimals: Int

    @State private var isHovering = false
    @State private var isDragging = false
    @State private var suppressDrag = false
    @State private var trackWidth: CGFloat = 0
    @State private var grabValue: Double = 0
    @State private var grabX: CGFloat = 0
    @State private var bandOffset: CGFloat = 0
    @State private var modifiers: EventModifiers = []
    @State private var valuePop = false
    @FocusState private var isFocused: Bool

    public init(
        _ label: String,
        value: Binding<Double>,
        in range: ClosedRange<Double> = 0...100,
        step: Double = 1,
        defaultValue: Double? = nil,
        decimals: Int = 0
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.step = step
        self.defaultValue = defaultValue
        self.decimals = decimals
    }

    public var body: some View {
        HStack(spacing: theme.metrics.spacing) {
            track
            GlitchValueText(formattedValue)
                .scaleEffect(valuePop ? 1.14 : 1)
        }
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

        return ZStack(alignment: .leading) {
            shape.fill(state.trackFill(palette))

            // Fill, knob and label move together under the rubber band, so
            // pushing past a limit shifts the whole row rather than sliding
            // one part against another.
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(palette.accent.opacity(isEnabled ? 0.9 : 0.45))
                    .frame(width: fillWidth)

                Rectangle()
                    .fill(palette.label.opacity(0.85))
                    .frame(width: metrics.knobWidth)
                    .offset(x: knobX)

                labelRow
            }
            .offset(x: bandOffset)
        }
        .frame(height: metrics.rowHeight)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(state.strokeColor(palette), lineWidth: state.strokeWidth)
        }
        .opacity(state.contentOpacity)
        .contentShape(Rectangle())
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { trackWidth = $0 }
        .gesture(dragGesture)
        .glitchHover { hovering in
            withAnimation(motion.snap) { isHovering = hovering }
        }
        .glitchScrollWheel(isActive: isHovering && isEnabled) { delta in
            adjust(by: Double(delta) * effectiveStep * 0.25)
        }
        .onModifierKeysChanged(mask: [.shift, .option]) { _, active in
            modifiers = active
        }
        .focusable(isEnabled)
        .focused($isFocused)
        .glitchFocusRing(isFocused: isFocused, radius: metrics.controlRadius)
        .onKeyPress(keys: [.leftArrow, .rightArrow]) { press in
            guard isEnabled else { return .ignored }
            let magnitude = effectiveStep * (press.modifiers.contains(.shift) ? 10 : 1)
            adjust(by: press.key == .leftArrow ? -magnitude : magnitude)
            return .handled
        }
        .animation(motion.pop, value: showsReset)
    }

    private var labelRow: some View {
        HStack(spacing: 4) {
            if showsReset {
                Button(action: reset) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: theme.metrics.iconSize))
                        .foregroundStyle(theme.palette.labelSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reset \(label)")
                .transition(.scale.combined(with: .opacity))
            }
            GlitchLabel(label)
        }
        .padding(.leading, theme.metrics.hInset)
    }

    // MARK: - Derived state

    private var state: ControlState {
        ControlState(
            isHovering: isHovering,
            isFocused: isFocused,
            isDragging: isDragging,
            isDisabled: !isEnabled
        )
    }

    private var formattedValue: String {
        GlitchNumberParsing.format(value, decimals: decimals)
    }

    private var fillWidth: CGFloat {
        trackWidth * CGFloat(GlitchValueMath.normalize(value, in: range))
    }

    private var knobX: CGFloat {
        let half = theme.metrics.knobWidth / 2
        return min(max(fillWidth - half, 0), max(0, trackWidth - theme.metrics.knobWidth))
    }

    /// Continuous sliders still need a stride for the keyboard and VoiceOver;
    /// a hundredth of the range is a sensible unit of "one press".
    private var effectiveStep: Double {
        step > 0 ? step : (range.upperBound - range.lowerBound) / 100
    }

    /// Where there is no pointer there is no hover, so the affordance is simply
    /// always present rather than hidden behind a gesture that would fight the
    /// track's own drag.
    private var showsReset: Bool {
        guard let defaultValue, isEnabled, value != defaultValue else { return false }
        return isHovering || !GlitchPlatform.hasPointer
    }

    // MARK: - Dragging

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                guard isEnabled, trackWidth > 0 else { return }

                if !isDragging {
                    beginDrag(at: gesture.location.x)
                    return
                }
                guard !suppressDrag else { return }

                let raw = modifiers.contains(.shift)
                    ? fineValue(at: gesture.location.x)
                    : rawValue(at: gesture.location.x)

                commit(raw)
                updateBand(atX: gesture.location.x, raw: raw)
            }
            .onEnded { _ in
                isDragging = false
                suppressDrag = false
                withAnimation(motion.glide) { bandOffset = 0 }
            }
    }

    private func beginDrag(at x: CGFloat) {
        isDragging = true
        isFocused = true

        // Option-click is a reset, not the start of a scrub.
        if modifiers.contains(.option), defaultValue != nil {
            suppressDrag = true
            reset()
            return
        }

        grabX = x
        grabValue = rawValue(at: x)
        commit(grabValue)
    }

    private func rawValue(at x: CGFloat) -> Double {
        guard trackWidth > 0 else { return range.lowerBound }
        let span = range.upperBound - range.lowerBound
        return range.lowerBound + Double(x / trackWidth) * span
    }

    /// Shift-drag moves a tenth as far, measured from where the drag started
    /// rather than from the pointer's absolute position.
    private func fineValue(at x: CGFloat) -> Double {
        guard trackWidth > 0 else { return grabValue }
        let span = range.upperBound - range.lowerBound
        return grabValue + Double((x - grabX) / trackWidth) * span * 0.1
    }

    private func commit(_ raw: Double) {
        let snapped = GlitchValueMath.snap(raw, step: step, in: range)
        guard snapped != value else { return }

        let wasAtLimit = value == range.lowerBound || value == range.upperBound
        let isAtLimit = snapped == range.lowerBound || snapped == range.upperBound

        // Motion rule 7: the fill tracks the finger exactly, with no spring
        // between them.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { value = snapped }

        if isAtLimit && !wasAtLimit {
            GlitchHaptics.limit()
        } else {
            GlitchHaptics.tick()
        }
    }

    private func updateBand(atX x: CGFloat, raw: Double) {
        let overshoot: CGFloat
        if raw > range.upperBound {
            overshoot = x - trackWidth
        } else if raw < range.lowerBound {
            overshoot = x
        } else {
            overshoot = 0
        }

        let resisted = GlitchValueMath.rubberBand(Double(overshoot), dimension: Double(trackWidth))

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { bandOffset = CGFloat(resisted) * 0.5 }
    }

    // MARK: - Discrete adjustment

    /// Keyboard, scroll wheel and VoiceOver all land here. Unlike dragging,
    /// these *do* animate: there is no finger for the fill to lag behind.
    private func adjust(by delta: Double) {
        guard isEnabled else { return }
        let next = GlitchValueMath.snap(value + delta, step: step, in: range)

        guard next != value else {
            GlitchHaptics.limit()
            return
        }

        withAnimation(motion.glide) { value = next }
        GlitchHaptics.tick()
        popValue()
    }

    private func reset() {
        guard let defaultValue else { return }
        withAnimation(motion.glide) { value = GlitchValueMath.clamp(defaultValue, to: range) }
        GlitchHaptics.impact()
        popValue()
    }

    /// A brief swell on the readout, so a value that changed without the user
    /// dragging it still registers as having changed.
    private func popValue() {
        withAnimation(motion.snap) { valuePop = true }
        withAnimation(motion.snap.delay(0.07)) { valuePop = false }
    }
}

#Preview("Slider") {
    @Previewable @State var flow = 73.0
    @Previewable @State var noise = 6.0
    @Previewable @State var tension = 24.0

    VStack(spacing: 8) {
        GlitchSlider("Flow", value: $flow, defaultValue: 50)
        GlitchSlider("Noise", value: $noise, defaultValue: 6)
        GlitchSlider("Tension", value: $tension, defaultValue: 50)
        GlitchSlider("Disabled", value: $flow).disabled(true)
    }
    .padding(24)
    .frame(width: 340)
    .background(GlitchPalette.dark.background)
    .glitchTheme()
    .preferredColorScheme(.dark)
}
