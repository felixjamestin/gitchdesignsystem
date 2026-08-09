import SwiftUI

/// A boolean, expressed as an Off/On pair.
///
/// The reference panel has no switches: every boolean is a two-segment control
/// with both states named. In a dense inspector that is the better trade — a
/// switch encodes its meaning purely in position and colour, so you have to
/// know the convention to read it, whereas "Off | On" says which one you are
/// looking at. It also keeps every boolean the same shape as every other
/// multiple-choice row.
///
/// `GlitchSwitch` remains available where a sliding switch is genuinely wanted.
public struct GlitchToggle: View {
    private let label: String
    @Binding private var isOn: Bool

    public init(_ label: String, isOn: Binding<Bool>) {
        self.label = label
        self._isOn = isOn
    }

    public var body: some View {
        GlitchSegmented(
            label,
            selection: $isOn,
            options: [
                GlitchOption("Off", value: false),
                GlitchOption("On", value: true),
            ]
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

/// A sliding switch, for the cases where one is genuinely wanted.
public struct GlitchSwitch: View {
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
        .glitchSurface(shape, fill: state.trackFill(theme.palette))
        .opacity(state.contentOpacity)
        .glitchPressable(isPressed: $isPressed, isEnabled: isEnabled, onTap: toggle)
        .glitchHover { hovering in
            withAnimation(motion.tint) { isHovering = hovering }
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
        let height = theme.metrics.rowHeight * 0.5
        let inset: CGFloat = 2.5
        let knob = height - inset * 2

        return Capsule()
            .fill(isOn ? theme.palette.handle.opacity(0.35) : theme.palette.trackActive)
            .frame(width: height * 1.75, height: height)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? theme.palette.handle : theme.palette.label)
                    // Stretches toward its destination while held, then
                    // settles — the squash that makes it feel physical.
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
        GlitchSound.commit()
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
        let shape = RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous)

        HStack(spacing: metrics.spacing) {
            box
            GlitchLabel(label)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, metrics.hInset)
        .frame(height: metrics.rowHeight)
        .glitchSurface(shape, fill: state.trackFill(theme.palette))
        .contentShape(Rectangle())
        .opacity(state.contentOpacity)
        .glitchPressable(isPressed: $isPressed, isEnabled: isEnabled, onTap: toggle)
        .glitchHover { hovering in
            withAnimation(motion.tint) { isHovering = hovering }
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
        let side = theme.metrics.markSize
        let shape = RoundedRectangle(cornerRadius: side * 0.28, style: .continuous)

        return shape
            .fill(isOn ? theme.palette.handle : theme.palette.trackActive)
            .frame(width: side, height: side)
            .overlay {
                // Trimmed rather than faded: a checkmark that draws itself
                // reads as a decision being made.
                GlitchCheckmark()
                    .trim(from: 0, to: isOn ? 1 : 0)
                    .stroke(
                        theme.palette.panel,
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
        GlitchSound.tick()
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

#Preview("Booleans") {
    @Previewable @State var grain = false
    @Previewable @State var loop = true
    @Previewable @State var trails = true

    VStack(spacing: 6) {
        GlitchToggle("Grain Animated", isOn: $grain)
        GlitchToggle("Loop", isOn: $loop)
        GlitchSwitch("Legacy switch", isOn: $loop)
        GlitchCheckbox("Show trails", isOn: $trails)
    }
    .padding(12)
    .frame(width: 280)
    .background(GlitchPalette.dark.panel)
    .glitchTheme()
    .preferredColorScheme(.dark)
}
