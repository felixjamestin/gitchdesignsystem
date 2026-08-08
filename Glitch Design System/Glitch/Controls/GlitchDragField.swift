import SwiftUI

/// A number you scrub by dragging sideways, or click to type exactly.
///
/// The move from Figma and After Effects: coarse adjustment is a drag, precise
/// adjustment is typing, and both live in the same small row. The distinction
/// is made on release — a press that travelled less than a few points was a
/// click and opens the editor; anything further was a scrub and commits.
public struct GlitchDragField: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.isEnabled) private var isEnabled

    private let label: String
    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let step: Double
    private let decimals: Int

    /// Points of travel per step. Loose enough to be controllable, tight
    /// enough that crossing a wide range doesn't require a second screen.
    private let pointsPerStep: CGFloat = 4

    @State private var isHovering = false
    @State private var isDragging = false
    @State private var grabValue: Double = 0
    @State private var isEditing = false
    @State private var draft = ""
    @State private var modifiers: EventModifiers = []
    @State private var wasFine = false
    @State private var anchorTranslation: CGFloat = 0
    @FocusState private var isFieldFocused: Bool

    public init(
        _ label: String,
        value: Binding<Double>,
        in range: ClosedRange<Double> = 0...100,
        step: Double = 1,
        decimals: Int = 0
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.step = step
        self.decimals = decimals
    }

    public var body: some View {
        let metrics = theme.metrics
        let shape = RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous)

        HStack(spacing: metrics.spacing) {
            GlitchLabel(label)
            Spacer(minLength: 4)
            readout
        }
        .padding(.horizontal, metrics.hInset)
        .frame(height: metrics.rowHeight)
        .glitchSurface(shape, fill: state.trackFill(theme.palette))
        .overlay { shape.strokeBorder(state.strokeColor(theme.palette), lineWidth: state.strokeWidth) }
        .opacity(state.contentOpacity)
        .contentShape(Rectangle())
        .gesture(scrubGesture)
        .glitchHover { hovering in
            withAnimation(motion.snap) { isHovering = hovering }
        }
        .glitchHorizontalScrubCursor(isActive: isHovering && isEnabled && !isEditing)
        .glitchModifierKeys { modifiers = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(GlitchNumberParsing.format(value, decimals: decimals))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: commit(value + effectiveStep, animated: true)
            case .decrement: commit(value - effectiveStep, animated: true)
            @unknown default: break
            }
        }
    }

    @ViewBuilder
    private var readout: some View {
        if isEditing {
            TextField("", text: $draft)
                .textFieldStyle(.plain)
                .focusEffectDisabled()
                .font(GlitchType.value(theme))
                .foregroundStyle(theme.palette.label)
                .multilineTextAlignment(.trailing)
                .focused($isFieldFocused)
                .frame(maxWidth: 80)
                .onSubmit(commitDraft)
                .onKeyPress(.escape) {
                    endEditing()
                    return .handled
                }
                .onChange(of: isFieldFocused) { _, focused in
                    // Clicking away is a commit, matching every other
                    // numeric field people use.
                    if !focused && isEditing { commitDraft() }
                }
        } else {
            GlitchValueText(GlitchNumberParsing.format(value, decimals: decimals), value: value)
                .foregroundStyle(theme.palette.label)
        }
    }

    private var state: ControlState {
        ControlState(
            isHovering: isHovering,
            isFocused: isFieldFocused,
            isDragging: isDragging,
            isDisabled: !isEnabled
        )
    }

    private var effectiveStep: Double {
        step > 0 ? step : (range.upperBound - range.lowerBound) / 100
    }

    // MARK: - Scrubbing

    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                guard isEnabled, !isEditing else { return }

                if !isDragging {
                    isDragging = true
                    grabValue = value
                    anchorTranslation = 0
                    wasFine = false
                }

                // Shift on a pointer, dragging away from the row under a
                // finger — same result, and re-anchored so switching between
                // them doesn't jump.
                let fine = modifiers.contains(.shift)
                    || abs(gesture.location.y - theme.metrics.rowHeight / 2) > theme.metrics.rowHeight * 1.5
                if fine != wasFine {
                    wasFine = fine
                    grabValue = value
                    anchorTranslation = gesture.translation.width
                }

                let travel = gesture.translation.width - anchorTranslation
                let steps = Double(travel / pointsPerStep) * (fine ? 0.1 : 1.0)
                commit(grabValue + steps * effectiveStep, animated: false)
            }
            .onEnded { gesture in
                guard isEnabled else { return }
                isDragging = false

                // A press that barely moved was a click, not a scrub.
                if abs(gesture.translation.width) < 3, abs(gesture.translation.height) < 3, !isEditing {
                    beginEditing()
                }
            }
    }

    private func commit(_ raw: Double, animated: Bool) {
        let snapped = GlitchValueMath.snap(raw, step: step, in: range)
        guard snapped != value else { return }

        if animated {
            withAnimation(motion.glide) { value = snapped }
        } else {
            // Motion rule 7 — no spring between the pointer and the number.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { value = snapped }
        }
        GlitchHaptics.tick()
    }

    // MARK: - Typing

    private func beginEditing() {
        draft = GlitchNumberParsing.format(value, decimals: decimals)
        withAnimation(motion.snap) { isEditing = true }
        isFieldFocused = true
    }

    private func commitDraft() {
        // An unparseable draft keeps the current value rather than zeroing it.
        commit(GlitchNumberParsing.parse(draft, fallback: value), animated: true)
        endEditing()
    }

    private func endEditing() {
        isFieldFocused = false
        withAnimation(motion.snap) { isEditing = false }
    }
}

#Preview("Drag field") {
    @Previewable @State var x = 12.0
    @Previewable @State var opacity = 80.0

    VStack(spacing: 8) {
        GlitchDragField("X", value: $x, in: -500...500)
        GlitchDragField("Opacity", value: $opacity)
        GlitchDragField("Disabled", value: $x).disabled(true)
    }
    .padding(24)
    .frame(width: 300)
    .background(GlitchPalette.dark.background)
    .glitchTheme()
    .preferredColorScheme(.dark)
}
