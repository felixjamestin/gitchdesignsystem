import SwiftUI

/// The container that makes a stack of controls read as one inspector.
public struct GlitchPanel<Content: View>: View {
    @Environment(\.glitchTheme) private var theme

    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        let metrics = theme.metrics
        let shape = RoundedRectangle(cornerRadius: metrics.panelRadius, style: .continuous)

        VStack(alignment: .leading, spacing: metrics.spacing) {
            content
        }
        .padding(metrics.panelPadding)
        .background(shape.fill(theme.palette.panel))
        .overlay { shape.strokeBorder(theme.palette.stroke, lineWidth: theme.metrics.borderWidth) }
    }
}

/// A collapsible group, with the disclosure chevron from the second reference.
public struct GlitchSection<Content: View>: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion

    private let title: String
    private let content: Content

    @State private var isExpanded: Bool
    @State private var isHovering = false

    public init(
        _ title: String,
        initiallyExpanded: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self._isExpanded = State(initialValue: initiallyExpanded)
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: theme.metrics.spacing) {
            header

            if isExpanded {
                VStack(alignment: .leading, spacing: theme.metrics.spacing) {
                    content
                }
                // Slides out from under the header rather than fading in
                // place, so the disclosure reads as one movement.
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .clipped()
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack {
            Text(title)
                .font(GlitchType.title(theme))
                .foregroundStyle(theme.palette.textPrimary)
            Spacer()
            Image(systemName: "chevron.down")
                .font(.system(size: theme.metrics.iconSize, weight: .medium))
                .foregroundStyle(
                    isHovering ? theme.palette.label : theme.palette.labelSecondary
                )
                .rotationEffect(.degrees(isExpanded ? 0 : -90))
        }
        .frame(height: theme.metrics.rowHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(motion.drift) { isExpanded.toggle() }
            GlitchHaptics.selection()
        }
        .glitchHover { hovering in
            withAnimation(motion.snap) { isHovering = hovering }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        .accessibilityAction {
            withAnimation(motion.drift) { isExpanded.toggle() }
        }
    }
}

/// A hairline rule.
public struct GlitchDivider: View {
    @Environment(\.glitchTheme) private var theme

    public init() {}

    public var body: some View {
        Rectangle()
            .fill(theme.palette.stroke)
            .frame(height: 1)
            .padding(.vertical, 2)
            .accessibilityHidden(true)
    }
}

#Preview("Panel") {
    @Previewable @State var flow = 73.0
    @Previewable @State var loop = true

    GlitchPanel {
        GlitchSection("Rotation") {
            GlitchSlider("X", value: $flow, in: -180...180)
            GlitchSlider("Y", value: $flow, in: -180...180)
        }
        GlitchDivider()
        GlitchSection("Options", initiallyExpanded: false) {
            GlitchToggle("Loop", isOn: $loop)
        }
    }
    .padding(24)
    .frame(width: 320)
    .background(GlitchPalette.dark.background)
    .glitchTheme()
    .preferredColorScheme(.dark)
}
