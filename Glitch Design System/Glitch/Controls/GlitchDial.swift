import SwiftUI

/// A rotary knob over a 270° arc.
///
/// Dragging accumulates the *rotation performed* rather than reading the
/// pointer's absolute angle. Absolute reading breaks the moment the pointer
/// crosses the seam behind the knob: the raw angle jumps by nearly a full turn
/// and the value leaps its whole range in one frame. `shortestDelta` collapses
/// that jump to the small rotation actually made.
public struct GlitchDial: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.isEnabled) private var isEnabled

    private let label: String
    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let step: Double
    private let decimals: Int

    private let sweep = GlitchAngleMath.defaultSweep

    @State private var isDragging = false
    @State private var isHovering = false
    @State private var lastPointerAngle: Double?
    @State private var center: CGPoint = .zero
    @FocusState private var isFocused: Bool

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
        VStack(spacing: 6) {
            dial
            GlitchLabel(label, secondary: true)
            GlitchValueText(GlitchNumberParsing.format(value, decimals: decimals))
                .foregroundStyle(theme.palette.label)
        }
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(GlitchNumberParsing.format(value, decimals: decimals))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: adjust(by: effectiveStep)
            case .decrement: adjust(by: -effectiveStep)
            @unknown default: break
            }
        }
    }

    private var dial: some View {
        let diameter = theme.metrics.rowHeight * 2.2
        let lineWidth = theme.metrics.rowHeight * 0.22

        return ZStack {
            Circle()
                .trim(from: 0, to: sweepFraction)
                .stroke(
                    theme.palette.track,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(startRotation)

            Circle()
                .trim(from: 0, to: sweepFraction * GlitchValueMath.normalize(value, in: range))
                .stroke(
                    theme.palette.accent,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(startRotation)

            // Pointer: a spoke, not a dot, so the angle is readable at a glance.
            Capsule()
                .fill(theme.palette.label)
                .frame(width: 2.5, height: diameter * 0.24)
                .offset(y: -diameter * 0.22)
                .rotationEffect(.radians(GlitchAngleMath.angle(forValue: value, sweep: sweep, in: range)))

            Circle()
                .fill(theme.palette.trackActive)
                .frame(width: diameter * 0.42, height: diameter * 0.42)
                .scaleEffect(isDragging ? 0.92 : (isHovering ? 1.04 : 1))
                .animation(motion.snap, value: isDragging)
                .animation(motion.snap, value: isHovering)
        }
        .frame(width: diameter, height: diameter)
        .padding(lineWidth / 2)
        .contentShape(Circle())
        .onGeometryChange(for: CGPoint.self) { proxy in
            CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
        } action: { center = $0 }
        .gesture(rotateGesture)
        .glitchHover { hovering in
            withAnimation(motion.snap) { isHovering = hovering }
        }
        .focusable(isEnabled)
        .focused($isFocused)
        .glitchFocusRing(isFocused: isFocused, radius: 999)
        .onKeyPress(keys: [.leftArrow, .rightArrow]) { press in
            guard isEnabled else { return .ignored }
            let magnitude = effectiveStep * (press.modifiers.contains(.shift) ? 10 : 1)
            adjust(by: press.key == .leftArrow ? -magnitude : magnitude)
            return .handled
        }
        .glitchScrollWheel(isActive: isHovering && isEnabled) { delta in
            adjust(by: Double(delta) * effectiveStep * 0.25)
        }
    }

    // MARK: - Geometry

    /// The fraction of a full turn the arc covers.
    private var sweepFraction: CGFloat {
        CGFloat(sweep / (2 * .pi))
    }

    /// Rotates the trimmed circle so its start sits at the arc's beginning,
    /// measured from straight up.
    private var startRotation: Angle {
        .radians(-(.pi / 2) - sweep / 2)
    }

    private var effectiveStep: Double {
        step > 0 ? step : (range.upperBound - range.lowerBound) / 100
    }

    // MARK: - Input

    private var rotateGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                guard isEnabled else { return }

                let dx = Double(gesture.location.x - center.x)
                let dy = Double(gesture.location.y - center.y)
                // Measured from straight up, clockwise positive.
                let pointerAngle = atan2(dx, -dy)

                guard let previous = lastPointerAngle else {
                    isDragging = true
                    isFocused = true
                    lastPointerAngle = pointerAngle
                    return
                }

                let delta = GlitchAngleMath.shortestDelta(from: previous, to: pointerAngle)
                lastPointerAngle = pointerAngle

                let span = range.upperBound - range.lowerBound
                let next = GlitchValueMath.snap(
                    value + delta / sweep * span,
                    step: step,
                    in: range
                )
                guard next != value else { return }

                // Motion rule 7 — no spring under the finger.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { value = next }
                GlitchHaptics.tick()
            }
            .onEnded { _ in
                isDragging = false
                lastPointerAngle = nil
            }
    }

    private func adjust(by delta: Double) {
        let next = GlitchValueMath.snap(value + delta, step: step, in: range)
        guard next != value else {
            GlitchHaptics.limit()
            return
        }
        withAnimation(motion.glide) { value = next }
        GlitchHaptics.tick()
    }
}

#Preview("Dial") {
    @Previewable @State var angle = 35.0
    @Previewable @State var depth = 80.0

    HStack(spacing: 20) {
        GlitchDial("Rotation", value: $angle, in: -180...180)
        GlitchDial("Depth", value: $depth)
    }
    .padding(24)
    .background(GlitchPalette.dark.background)
    .glitchTheme()
    .preferredColorScheme(.dark)
}
