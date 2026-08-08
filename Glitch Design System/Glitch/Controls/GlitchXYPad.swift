import SwiftUI

/// Two parameters on one surface.
///
/// The knob tracks the finger exactly while dragging and springs only on
/// release (motion rule 7) — a two-dimensional control makes lag between input
/// and response especially obvious, because the error is visible in a
/// direction the finger isn't even moving.
public struct GlitchXYPad: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.isEnabled) private var isEnabled

    private let label: String
    @Binding private var x: Double
    @Binding private var y: Double
    private let xRange: ClosedRange<Double>
    private let yRange: ClosedRange<Double>

    @State private var size: CGSize = .zero
    @State private var isDragging = false
    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    public init(
        _ label: String,
        x: Binding<Double>,
        y: Binding<Double>,
        xRange: ClosedRange<Double> = 0...100,
        yRange: ClosedRange<Double> = 0...100
    ) {
        self.label = label
        self._x = x
        self._y = y
        self.xRange = xRange
        self.yRange = yRange
    }

    public var body: some View {
        let metrics = theme.metrics
        let shape = RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous)

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                GlitchLabel(label, secondary: true)
                Spacer()
                GlitchValueText(
                    "\(GlitchNumberParsing.format(x, decimals: 0)), \(GlitchNumberParsing.format(y, decimals: 0))"
                )
            }

            ZStack {
                shape.fill(state.trackFill(theme.palette))
                grid
                crosshair
                knob
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(shape)
            .overlay { shape.strokeBorder(state.strokeColor(theme.palette), lineWidth: state.strokeWidth) }
            .contentShape(Rectangle())
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            .gesture(dragGesture)
            .glitchHover { hovering in
                withAnimation(motion.snap) { isHovering = hovering }
            }
            .focusable(isEnabled)
            .focused($isFocused)
            .glitchFocusRing(isFocused: isFocused, radius: metrics.controlRadius)
            .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { press in
                guard isEnabled else { return .ignored }
                let amount = press.modifiers.contains(.shift) ? 10.0 : 1.0
                nudge(key: press.key, amount: amount)
                return .handled
            }
        }
        .opacity(state.contentOpacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(
            "X \(GlitchNumberParsing.format(x, decimals: 0)), Y \(GlitchNumberParsing.format(y, decimals: 0))"
        )
    }

    // MARK: - Parts

    private var grid: some View {
        GeometryReader { proxy in
            Path { path in
                let w = proxy.size.width
                let h = proxy.size.height
                path.move(to: CGPoint(x: w / 2, y: 0))
                path.addLine(to: CGPoint(x: w / 2, y: h))
                path.move(to: CGPoint(x: 0, y: h / 2))
                path.addLine(to: CGPoint(x: w, y: h / 2))
            }
            .stroke(theme.palette.stroke, lineWidth: 1)
        }
    }

    private var crosshair: some View {
        GeometryReader { proxy in
            let point = position(in: proxy.size)
            Path { path in
                path.move(to: CGPoint(x: point.x, y: 0))
                path.addLine(to: CGPoint(x: point.x, y: proxy.size.height))
                path.move(to: CGPoint(x: 0, y: point.y))
                path.addLine(to: CGPoint(x: proxy.size.width, y: point.y))
            }
            .stroke(theme.palette.accent.opacity(0.35), lineWidth: 1)
        }
    }

    private var knob: some View {
        GeometryReader { proxy in
            let point = position(in: proxy.size)
            Circle()
                .fill(theme.palette.accent)
                .frame(width: theme.metrics.markSize * 0.8, height: theme.metrics.markSize * 0.8)
                .overlay { Circle().strokeBorder(theme.palette.onAccent.opacity(0.6), lineWidth: 1.5) }
                .scaleEffect(isDragging ? 1.25 : 1)
                .position(point)
                .animation(motion.snap, value: isDragging)
        }
    }

    private func position(in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width * GlitchValueMath.normalize(x, in: xRange),
            // Screen y grows downward; the value grows upward, as people expect
            // of a graph.
            y: size.height * (1 - GlitchValueMath.normalize(y, in: yRange))
        )
    }

    private var state: ControlState {
        ControlState(
            isHovering: isHovering,
            isFocused: isFocused,
            isDragging: isDragging,
            isDisabled: !isEnabled
        )
    }

    // MARK: - Input

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                guard isEnabled, size.width > 0, size.height > 0 else { return }
                if !isDragging {
                    isDragging = true
                    isFocused = true
                }

                let fx = GlitchValueMath.fraction(ofX: Double(gesture.location.x), width: Double(size.width))
                let fy = GlitchValueMath.fraction(ofX: Double(gesture.location.y), width: Double(size.height))

                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    x = GlitchValueMath.denormalize(fx, in: xRange)
                    y = GlitchValueMath.denormalize(1 - fy, in: yRange)
                }
            }
            .onEnded { _ in
                withAnimation(motion.glide) { isDragging = false }
                GlitchHaptics.tick()
            }
    }

    private func nudge(key: KeyEquivalent, amount: Double) {
        withAnimation(motion.glide) {
            switch key {
            case .leftArrow: x = GlitchValueMath.clamp(x - amount, to: xRange)
            case .rightArrow: x = GlitchValueMath.clamp(x + amount, to: xRange)
            case .upArrow: y = GlitchValueMath.clamp(y + amount, to: yRange)
            case .downArrow: y = GlitchValueMath.clamp(y - amount, to: yRange)
            default: break
            }
        }
        GlitchHaptics.tick()
    }
}

#Preview("XY pad") {
    @Previewable @State var x = 30.0
    @Previewable @State var y = 70.0

    GlitchXYPad("Displacement", x: $x, y: $y)
        .padding(24)
        .frame(width: 300)
        .background(GlitchPalette.dark.background)
        .glitchTheme()
        .preferredColorScheme(.dark)
}
