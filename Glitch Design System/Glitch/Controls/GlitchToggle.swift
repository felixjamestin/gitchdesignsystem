import SwiftUI

/// An on/off switch in a labelled row.
public struct GlitchToggle: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.isEnabled) private var isEnabled

    private let label: String
    @Binding private var isOn: Bool

    @State private var isHovering = false
    @State private var isPressed = false
    @FocusState private var isFocused: Bool

    public init(_ label: String, isOn: Binding<Bool>) {
        self.label = label
        self._isOn = isOn
    }

    public var body: some View {
        let metrics = theme.metrics
        let shape = RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous)

        HStack(spacing: metrics.spacing) {
            GlitchLabel(label)
            Spacer(minLength: 4)
            switchTrack
        }
        .padding(.horizontal, metrics.hInset)
        .frame(height: metrics.rowHeight)
        .background(shape.fill(state.trackFill(theme.palette)))
        .overlay { shape.strokeBorder(state.strokeColor(theme.palette), lineWidth: state.strokeWidth) }
        .opacity(state.contentOpacity)
        .scaleEffect(state.pressScale)
        .glitchPressable(isPressed: $isPressed, isEnabled: isEnabled, onTap: toggle)
        .glitchHover { hovering in
            withAnimation(motion.snap) { isHovering = hovering }
        }
        .focusable(isEnabled)
        .focused($isFocused)
        .glitchFocusRing(isFocused: isFocused, radius: metrics.controlRadius)
        .onKeyPress(.space) {
            guard isEnabled else { return .ignored }
            toggle()
            return .handled
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAction { toggle() }
    }

    private var switchTrack: some View {
        let metrics = theme.metrics
        let height = metrics.rowHeight * 0.52
        let inset: CGFloat = 2.5
        let knob = height - inset * 2

        return Capsule()
            .fill(isOn ? theme.palette.accent : theme.palette.trackActive)
            .frame(width: metrics.toggleWidth, height: height)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? theme.palette.onAccent : theme.palette.label)
                    // The knob stretches toward its destination while held,
                    // then settles — the squash that makes it feel physical
                    // rather than teleported.
                    .frame(width: isPressed ? knob * 1.35 : knob, height: knob)
                    .padding(inset)
            }
            .animation(motion.snap, value: isOn)
            .animation(motion.snap, value: isPressed)
    }

    private var state: ControlState {
        ControlState(
            isHovering: isHovering,
            isPressed: isPressed,
            isFocused: isFocused,
            isDisabled: !isEnabled
        )
    }

    private func toggle() {
        withAnimation(motion.snap) { isOn.toggle() }
        GlitchHaptics.impact()
    }
}

/// A checkbox with a checkmark that draws itself in.
public struct GlitchCheckbox: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.isEnabled) private var isEnabled

    private let label: String
    @Binding private var isOn: Bool

    @State private var isHovering = false
    @State private var isPressed = false
    @FocusState private var isFocused: Bool

    public init(_ label: String, isOn: Binding<Bool>) {
        self.label = label
        self._isOn = isOn
    }

    public var body: some View {
        let metrics = theme.metrics

        HStack(spacing: metrics.spacing) {
            box
            GlitchLabel(label)
            Spacer(minLength: 0)
        }
        .frame(height: metrics.rowHeight)
        .contentShape(Rectangle())
        .opacity(state.contentOpacity)
        .scaleEffect(state.pressScale)
        .glitchPressable(isPressed: $isPressed, isEnabled: isEnabled, onTap: toggle)
        .glitchHover { hovering in
            withAnimation(motion.snap) { isHovering = hovering }
        }
        .focusable(isEnabled)
        .focused($isFocused)
        .glitchFocusRing(isFocused: isFocused, radius: metrics.controlRadius)
        .onKeyPress(.space) {
            guard isEnabled else { return .ignored }
            toggle()
            return .handled
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? "Checked" : "Unchecked")
        .accessibilityAction { toggle() }
    }

    private var box: some View {
        let metrics = theme.metrics
        let side = metrics.markSize
        let shape = RoundedRectangle(cornerRadius: side * 0.28, style: .continuous)

        return shape
            .fill(isOn ? theme.palette.accent : state.trackFill(theme.palette))
            .frame(width: side, height: side)
            .overlay {
                shape.strokeBorder(
                    isOn ? Color.clear : state.strokeColor(theme.palette),
                    lineWidth: state.strokeWidth
                )
            }
            .overlay {
                // Trimmed rather than faded: a checkmark that draws itself
                // reads as a decision being made.
                GlitchCheckmark()
                    .trim(from: 0, to: isOn ? 1 : 0)
                    .stroke(
                        theme.palette.onAccent,
                        style: StrokeStyle(lineWidth: side * 0.14, lineCap: .round, lineJoin: .round)
                    )
                    .padding(side * 0.26)
            }
            .animation(motion.snap, value: isOn)
    }

    private var state: ControlState {
        ControlState(
            isHovering: isHovering,
            isPressed: isPressed,
            isFocused: isFocused,
            isDisabled: !isEnabled
        )
    }

    private func toggle() {
        withAnimation(motion.snap) { isOn.toggle() }
        GlitchHaptics.selection()
    }
}

/// The checkmark path, drawn left-to-right so trimming animates as a stroke.
struct GlitchCheckmark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.05))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

#Preview("Toggles") {
    @Previewable @State var loop = true
    @Previewable @State var mirror = false
    @Previewable @State var trails = true

    VStack(spacing: 8) {
        GlitchToggle("Loop", isOn: $loop)
        GlitchToggle("Mirror", isOn: $mirror)
        GlitchToggle("Disabled", isOn: $loop).disabled(true)
        GlitchCheckbox("Show trails", isOn: $trails)
        GlitchCheckbox("Snap to grid", isOn: $mirror)
    }
    .padding(24)
    .frame(width: 320)
    .background(GlitchPalette.dark.background)
    .glitchTheme()
    .preferredColorScheme(.dark)
}
