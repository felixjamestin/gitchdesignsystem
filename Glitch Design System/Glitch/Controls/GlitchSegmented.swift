import SwiftUI

/// A row of mutually exclusive choices with a sliding pill.
///
/// The pill is one view moved between segments, not a per-segment highlight
/// cross-fading. Cross-fading discards the relationship between where the
/// selection was and where it went, which is the only reason to prefer a
/// segmented control over a select in the first place.
///
/// The first appearance is deliberately instant. Sliding the pill in from
/// wherever it happened to be initialised animates a change the user did not
/// make.
public struct GlitchSegmented<Value: Hashable>: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.isEnabled) private var isEnabled

    private let label: String?
    @Binding private var selection: Value
    private let options: [GlitchOption<Value>]

    @Namespace private var pill
    @State private var hasAppeared = false
    @State private var isHovering = false

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
        let metrics = theme.metrics
        let shape = RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous)

        HStack(spacing: metrics.spacing) {
            if let label {
                GlitchLabel(label)
                Spacer(minLength: 8)
            }
            segments
                .frame(maxWidth: label == nil ? .infinity : nil)
        }
        .padding(.leading, label == nil ? 0 : metrics.hInset)
        .frame(height: metrics.rowHeight)
        .background(shape.fill(isHovering && isEnabled ? theme.palette.trackHover : theme.palette.track))
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                metrics.tracksAreOutlined ? theme.palette.stroke : .clear,
                lineWidth: metrics.borderWidth
            )
        }
        .opacity(isEnabled ? 1 : 0.4)
        .glitchHover { hovering in
            withAnimation(motion.tint) { isHovering = hovering }
        }
        .animation(motion.tint, value: isHovering)
        .onAppear { hasAppeared = true }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label ?? "Options")
    }

    private var segments: some View {
        HStack(spacing: 0) {
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
    }

    private func segment(for option: GlitchOption<Value>) -> some View {
        let metrics = theme.metrics
        let isSelected = option.value == selection

        return ZStack {
            if isSelected {
                RoundedRectangle(cornerRadius: max(2, metrics.controlRadius - 2), style: .continuous)
                    .fill(theme.palette.trackActive)
                    .matchedGeometryEffect(id: "pill", in: pill)
            }

            HStack(spacing: 4) {
                if let systemImage = option.systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: metrics.iconSize, weight: .medium))
                }
                GlitchType.labelText(option.title, theme)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? theme.palette.textPrimary : theme.palette.label)
            .padding(.horizontal, 12)
            .animation(motion.tint, value: isSelected)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { select(option.value) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { select(option.value) }
    }

    private func select(_ value: Value) {
        guard isEnabled, value != selection else { return }
        // Instant before the first layout has settled, so the pill never
        // animates in from nowhere.
        if hasAppeared {
            withAnimation(motion.snap) { selection = value }
        } else {
            selection = value
        }
        GlitchHaptics.selection()
    }
}

#Preview("Segmented") {
    @Previewable @State var blend = "add"
    @Previewable @State var align = "center"

    VStack(spacing: 6) {
        GlitchSegmented("Blend", selection: $blend, options: [
            GlitchOption("Add", value: "add"),
            GlitchOption("Screen", value: "screen"),
        ])
        GlitchSegmented(selection: $align, options: [
            GlitchOption("Left", value: "left"),
            GlitchOption("Center", value: "center"),
            GlitchOption("Right", value: "right"),
        ])
    }
    .padding(12)
    .frame(width: 280)
    .background(GlitchPalette.dark.panel)
    .glitchTheme()
    .preferredColorScheme(.dark)
}
