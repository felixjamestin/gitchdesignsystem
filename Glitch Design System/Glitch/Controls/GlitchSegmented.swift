import SwiftUI

/// A row of mutually exclusive choices with a sliding indicator.
///
/// The indicator is one view moved with `matchedGeometryEffect` rather than a
/// per-segment highlight cross-fading. Cross-fading loses the relationship
/// between where the selection was and where it went; sliding preserves it,
/// which is the whole reason to use a segmented control over a select.
public struct GlitchSegmented<Value: Hashable>: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.isEnabled) private var isEnabled

    private let label: String?
    @Binding private var selection: Value
    private let options: [GlitchOption<Value>]

    @Namespace private var indicatorNamespace
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
        VStack(alignment: .leading, spacing: 4) {
            if let label {
                GlitchLabel(label, secondary: true)
            }
            control
        }
        .opacity(isEnabled ? 1 : 0.4)
    }

    private var control: some View {
        let metrics = theme.metrics
        let shape = RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous)

        return HStack(spacing: 2) {
            if options.isEmpty {
                GlitchLabel("No options", secondary: true)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(options) { option in
                    segment(for: option)
                }
            }
        }
        .padding(2)
        .frame(height: metrics.rowHeight)
        .background(shape.fill(theme.palette.track))
        .overlay { shape.strokeBorder(theme.palette.stroke, lineWidth: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label ?? "Options")
    }

    private func segment(for option: GlitchOption<Value>) -> some View {
        let metrics = theme.metrics
        let isSelected = option.value == selection
        let innerRadius = max(2, metrics.controlRadius - 2)

        return ZStack {
            if isSelected {
                RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                    .fill(theme.palette.accent)
                    .matchedGeometryEffect(id: "indicator", in: indicatorNamespace)
            } else if hovered == option.value {
                RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                    .fill(theme.palette.trackHover)
            }

            HStack(spacing: 4) {
                if let systemImage = option.systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: metrics.iconSize, weight: .semibold))
                }
                Text(option.title.uppercased())
                    .font(GlitchType.label(metrics))
                    .tracking(0.7)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? theme.palette.onAccent : theme.palette.label)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private func select(_ value: Value) {
        guard isEnabled, value != selection else { return }
        withAnimation(motion.glide) { selection = value }
        GlitchHaptics.selection()
    }
}

#Preview("Segmented") {
    @Previewable @State var blend = "Add"
    @Previewable @State var align = "left"

    VStack(spacing: 12) {
        GlitchSegmented(
            "Blend",
            selection: $blend,
            options: GlitchOption.list(["Add", "Screen", "Multiply"])
        )
        GlitchSegmented(
            "Align",
            selection: $align,
            options: [
                GlitchOption("Left", value: "left", systemImage: "text.alignleft"),
                GlitchOption("Center", value: "center", systemImage: "text.aligncenter"),
                GlitchOption("Right", value: "right", systemImage: "text.alignright"),
            ]
        )
    }
    .padding(24)
    .frame(width: 340)
    .background(GlitchPalette.dark.background)
    .glitchTheme()
    .preferredColorScheme(.dark)
}
