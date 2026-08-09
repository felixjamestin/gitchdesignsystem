import SwiftUI

/// A vertical list of mutually exclusive choices.
///
/// The whole row is the target, not just the dot — a four-point circle is a
/// pointer-only affordance and would be unusable under a thumb.
public struct GlitchRadioGroup<Value: Hashable>: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.isEnabled) private var isEnabled

    private let label: String?
    @Binding private var selection: Value
    private let options: [GlitchOption<Value>]

    @State private var hovered: Value?

    public init(
        _ label: String? = nil,
        selection: Binding<Value>,
        options: [GlitchOption<Value>]
    ) {
        self.label = label
        self._selection = selection
        self.options = options
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let label {
                GlitchLabel(label, secondary: true)
                    .padding(.bottom, 2)
            }

            if options.isEmpty {
                GlitchLabel("No options", secondary: true)
                    .frame(height: theme.metrics.rowHeight)
            } else {
                ForEach(options) { option in
                    row(for: option)
                }
            }
        }
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label ?? "Options")
    }

    private func row(for option: GlitchOption<Value>) -> some View {
        let metrics = theme.metrics
        let isSelected = option.value == selection

        return HStack(spacing: metrics.spacing) {
            dot(isSelected: isSelected)
            GlitchLabel(option.title)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, metrics.hInset)
        .frame(height: metrics.rowHeight)
        .background {
            RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous)
                .fill(hovered == option.value ? theme.palette.trackHover.opacity(0.6) : .clear)
        }
        .contentShape(Rectangle())
        .onTapGesture { select(option.value) }
        .glitchHover { hovering in
            withAnimation(motion.snap) { hovered = hovering ? option.value : nil }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { select(option.value) }
    }

    private func dot(isSelected: Bool) -> some View {
        let side = theme.metrics.markSize

        return Circle()
            .strokeBorder(
                isSelected ? theme.palette.accent : theme.palette.labelSecondary,
                lineWidth: isSelected ? 2 : 1.5
            )
            .frame(width: side, height: side)
            .overlay {
                Circle()
                    .fill(theme.palette.accent)
                    .frame(width: side * 0.46, height: side * 0.46)
                    .scaleEffect(isSelected ? 1 : 0.01)
                    .opacity(isSelected ? 1 : 0)
            }
            .animation(motion.snap, value: isSelected)
    }

    private func select(_ value: Value) {
        guard isEnabled, value != selection else { return }
        withAnimation(motion.snap) { selection = value }
        GlitchHaptics.selection()
        GlitchSound.tick()
    }
}

#Preview("Radio group") {
    @Previewable @State var mode = "Flow"

    VStack(alignment: .leading, spacing: 12) {
        GlitchRadioGroup(
            "Mode",
            selection: $mode,
            options: GlitchOption.list(["Flow", "Scatter", "Echo"])
        )
        GlitchRadioGroup(
            "Empty",
            selection: $mode,
            options: []
        )
    }
    .padding(24)
    .frame(width: 300)
    .background(GlitchPalette.dark.background)
    .glitchTheme()
    .preferredColorScheme(.dark)
}
