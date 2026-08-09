import SwiftUI

/// A value with decrement and increment buttons.
///
/// Holding a button repeats, accelerating the longer it's held: the first
/// press is one step for precision, and a long hold crosses a wide range
/// without becoming a chore.
public struct GlitchStepper: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.isEnabled) private var isEnabled

    private let label: String
    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let step: Double
    private let decimals: Int

    @State private var isHovering = false
    @State private var isRepeating = false
    @State private var repeatTask: Task<Void, Never>?

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

            // Buttons first, number last.
            //
            // The number belongs at the trailing edge like every other
            // readout in the system — a column of rows whose values line up
            // can be scanned, and one where a stepper's number sits four
            // points further in cannot.
            HStack(spacing: 4) {
                button(systemImage: "minus", delta: -step, enabled: value > range.lowerBound)
                button(systemImage: "plus", delta: step, enabled: value < range.upperBound)
            }

            GlitchValueText(
                GlitchNumberParsing.format(value, decimals: decimals),
                value: value,
                animated: !isRepeating
            )
            .foregroundStyle(theme.palette.label)
        }
        .padding(.horizontal, metrics.hInset)
        .frame(height: metrics.rowHeight)
        .glitchSurface(shape, fill: state.trackFill(theme.palette))
        .overlay { shape.strokeBorder(state.strokeColor(theme.palette), lineWidth: state.strokeWidth) }
        .opacity(state.contentOpacity)
        .glitchHover { hovering in
            withAnimation(motion.snap) { isHovering = hovering }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(GlitchNumberParsing.format(value, decimals: decimals))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: adjust(by: step)
            case .decrement: adjust(by: -step)
            @unknown default: break
            }
        }
    }

    private func button(systemImage: String, delta: Double, enabled: Bool) -> some View {
        let side = theme.metrics.rowHeight - 8

        return StepperButton(
            systemImage: systemImage,
            side: side,
            isEnabled: isEnabled && enabled,
            onPress: { startRepeating(delta) },
            onRelease: stopRepeating
        )
        .accessibilityHidden(true)
    }

    private var state: ControlState {
        ControlState(isHovering: isHovering, isDisabled: !isEnabled)
    }

    /// A single press rolls the digits; a held one doesn't.
    ///
    /// The repeat reaches one step every 28ms, and a roll takes an order of
    /// magnitude longer than that — animating each would stack a queue of
    /// half-finished transitions and turn the number into a smear. Held
    /// repeats set the value outright, which also reads as more responsive.
    private func adjust(by delta: Double, animated: Bool = true) {
        let next = GlitchValueMath.snap(value + delta, step: step, in: range)
        guard next != value else {
            stopRepeating()
            GlitchHaptics.limit()
            GlitchSound.reject()
            return
        }

        if animated {
            withAnimation(motion.snap) { value = next }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { value = next }
        }
        GlitchHaptics.tick()
        GlitchSound.tick()
    }

    private func startRepeating(_ delta: Double) {
        guard isEnabled else { return }
        adjust(by: delta)

        repeatTask?.cancel()
        repeatTask = Task { @MainActor in
            // A held button shouldn't run away immediately — the pause is what
            // makes a single tap possible.
            try? await Task.sleep(for: .milliseconds(450))

            guard !Task.isCancelled else { return }
            isRepeating = true

            var interval = 120
            while !Task.isCancelled {
                adjust(by: delta, animated: false)
                try? await Task.sleep(for: .milliseconds(interval))
                interval = max(28, interval - 12)
            }
        }
    }

    private func stopRepeating() {
        repeatTask?.cancel()
        repeatTask = nil
        isRepeating = false
    }
}

/// Split out so each button owns its own press state.
private struct StepperButton: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion

    let systemImage: String
    let side: CGFloat
    let isEnabled: Bool
    let onPress: () -> Void
    let onRelease: () -> Void

    @State private var isPressed = false
    @State private var isHovering = false

    var body: some View {
        RoundedRectangle(cornerRadius: side * 0.3, style: .continuous)
            .fill(fill)
            .frame(width: side, height: side)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: theme.metrics.iconSize, weight: .bold))
                    .foregroundStyle(theme.palette.label)
            }
            .opacity(isEnabled ? 1 : 0.35)
            .scaleEffect(isPressed ? 0.92 : 1)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard isEnabled, !isPressed else { return }
                        withAnimation(motion.snap) { isPressed = true }
                        onPress()
                    }
                    .onEnded { _ in
                        withAnimation(motion.snap) { isPressed = false }
                        onRelease()
                    }
            )
            .glitchHover { hovering in
                withAnimation(motion.snap) { isHovering = hovering }
            }
    }

    private var fill: Color {
        if isPressed { return theme.palette.handle.opacity(0.25) }
        return isHovering ? theme.palette.trackHover : theme.palette.trackActive.opacity(0.6)
    }
}

#Preview("Stepper") {
    @Previewable @State var count = 4.0

    VStack(spacing: 8) {
        GlitchStepper("Copies", value: $count, in: 1...64)
        GlitchStepper("Disabled", value: $count).disabled(true)
    }
    .padding(24)
    .frame(width: 300)
    .background(GlitchPalette.dark.background)
    .glitchTheme()
    .preferredColorScheme(.dark)
}
