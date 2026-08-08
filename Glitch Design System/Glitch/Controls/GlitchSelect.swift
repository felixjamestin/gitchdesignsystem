import SwiftUI

/// A dropdown whose list is ours, not the system's.
///
/// SwiftUI's `Menu` renders as an AppKit menu on macOS and an action sheet or
/// inline picker on iOS — three appearances with nothing in common, none of
/// them this system's. So the list is built here.
///
/// Presentation goes through `.popover` with compact adaptation forced, which
/// buys window-level layering, dismissal on outside tap, and a system
/// scale-from-anchor transition that already satisfies motion rule 4. Only the
/// contents are ours — which is the part that has to match. A hand-rolled
/// overlay would have to reimplement outside-tap dismissal and would still be
/// clipped by whatever panel contained it.
public struct GlitchSelect<Value: Hashable>: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.isEnabled) private var isEnabled

    private let label: String?
    @Binding private var selection: Value
    private let options: [GlitchOption<Value>]
    private let placeholder: String

    @State private var isOpen = false
    @State private var isHovering = false
    @State private var highlighted: Value?
    @FocusState private var isFocused: Bool

    public init(
        _ label: String? = nil,
        selection: Binding<Value>,
        options: [GlitchOption<Value>],
        placeholder: String = "Select"
    ) {
        self.label = label
        self._selection = selection
        self.options = options
        self.placeholder = placeholder
    }

    public var body: some View {
        let metrics = theme.metrics
        let shape = RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous)

        HStack(spacing: metrics.spacing) {
            if let label {
                GlitchLabel(label, secondary: true)
            }
            Spacer(minLength: 4)
            Text(selectedTitle)
                .font(GlitchType.value(theme))
                .foregroundStyle(theme.palette.label)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: metrics.iconSize * 0.8, weight: .semibold))
                .foregroundStyle(theme.palette.labelSecondary)
                .rotationEffect(.degrees(isOpen ? 180 : 0))
        }
        .padding(.horizontal, metrics.hInset)
        .frame(height: metrics.rowHeight)
        .glitchSurface(shape, fill: state.trackFill(theme.palette))
        .overlay { shape.strokeBorder(state.strokeColor(theme.palette), lineWidth: state.strokeWidth) }
        .opacity(state.contentOpacity)
        .contentShape(Rectangle())
        .onTapGesture { open() }
        .glitchHover { hovering in
            withAnimation(motion.snap) { isHovering = hovering }
        }
        .focusable(isEnabled)
        .focused($isFocused)
        .glitchFocusRing(isFocused: isFocused, radius: metrics.controlRadius)
        .onKeyPress(.return) {
            guard isEnabled else { return .ignored }
            open()
            return .handled
        }
        .animation(motion.snap, value: isOpen)
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            list
                .presentationCompactAdaptation(.popover)
                .presentationBackground(theme.palette.panel)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "Select")
        .accessibilityValue(selectedTitle)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { open() }
    }

    // MARK: - List

    private var list: some View {
        VStack(alignment: .leading, spacing: 1) {
            if options.isEmpty {
                // An empty list must still render something sane.
                GlitchLabel("No options", secondary: true)
                    .padding(.horizontal, theme.metrics.hInset)
                    .frame(height: theme.metrics.rowHeight, alignment: .leading)
            } else {
                ForEach(options) { option in
                    row(for: option)
                }
            }
        }
        .padding(4)
        .frame(minWidth: 180)
        .background(theme.palette.panel)
        // Focusable purely to receive arrow keys — it must not draw a ring of
        // its own around the whole list.
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(keys: [.upArrow, .downArrow]) { press in
            moveHighlight(by: press.key == .downArrow ? 1 : -1)
            return .handled
        }
        .onKeyPress(.return) {
            if let highlighted { select(highlighted) }
            return .handled
        }
        .onKeyPress(.escape) {
            isOpen = false
            return .handled
        }
        .onAppear { highlighted = selection }
    }

    private func row(for option: GlitchOption<Value>) -> some View {
        let metrics = theme.metrics
        let isSelected = option.value == selection
        let isHighlighted = option.value == highlighted

        return HStack(spacing: metrics.spacing) {
            if let systemImage = option.systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: metrics.iconSize))
                    .foregroundStyle(theme.palette.labelSecondary)
            }
            Text(option.title)
                .font(GlitchType.value(theme))
                .foregroundStyle(theme.palette.label)
            Spacer(minLength: 12)
            Image(systemName: "checkmark")
                .font(.system(size: metrics.iconSize * 0.9, weight: .semibold))
                .foregroundStyle(theme.palette.textPrimary)
                .opacity(isSelected ? 1 : 0)
        }
        .padding(.horizontal, metrics.hInset)
        .frame(height: metrics.rowHeight, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: metrics.controlRadius * 0.7, style: .continuous)
                .fill(isHighlighted ? theme.palette.trackHover : .clear)
        }
        .contentShape(Rectangle())
        .onTapGesture { select(option.value) }
        .glitchHover { hovering in
            if hovering { highlighted = option.value }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { select(option.value) }
    }

    // MARK: - Behavior

    private var selectedTitle: String {
        options.first { $0.value == selection }?.title ?? placeholder
    }

    private var state: ControlState {
        ControlState(
            isHovering: isHovering,
            isPressed: isOpen,
            isFocused: isFocused,
            isDisabled: !isEnabled
        )
    }

    private func open() {
        guard isEnabled, !options.isEmpty else { return }
        highlighted = selection
        isOpen = true
    }

    private func select(_ value: Value) {
        selection = value
        isOpen = false
        GlitchHaptics.selection()
    }

    private func moveHighlight(by offset: Int) {
        guard !options.isEmpty else { return }
        let current = options.firstIndex { $0.value == highlighted } ?? 0
        let next = (current + offset + options.count) % options.count
        withAnimation(motion.snap) { highlighted = options[next].value }
    }
}

#Preview("Select") {
    @Previewable @State var easing = "Spring"
    @Previewable @State var empty = "none"

    VStack(spacing: 10) {
        GlitchSelect(
            "Easing",
            selection: $easing,
            options: GlitchOption.list(["Linear", "Ease In", "Ease Out", "Spring"])
        )
        GlitchSelect("Empty", selection: $empty, options: [])
        GlitchSelect(
            "Disabled",
            selection: $easing,
            options: GlitchOption.list(["Linear"])
        )
        .disabled(true)
    }
    .padding(24)
    .frame(width: 320)
    .background(GlitchPalette.dark.background)
    .glitchTheme()
    .preferredColorScheme(.dark)
}
