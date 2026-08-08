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
        .glitchSurface(shape, fill: theme.palette.panel)
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
                    // Each row is reached individually so it can carry its own
                    // delay. A section that opens all at once tells you it
                    // changed; one that unrolls tells you what it contains and
                    // in what order.
                    Group(subviews: content) { rows in
                        ForEach(rows.indices, id: \.self) { index in
                            rows[index]
                                .transition(stagger(index: index, of: rows.count))
                        }
                    }
                }
            }
        }
        .clipped()
        .accessibilityElement(children: .contain)
    }

    /// Opens downward from the header and closes upward toward it, so the
    /// section always appears to move from the thing you clicked. Closing runs
    /// on the quicker token — waiting out a leisurely stagger to get rid of
    /// something you just dismissed is irritating.
    private func stagger(index: Int, of count: Int) -> AnyTransition {
        let entering = AnyTransition
            .offset(y: -10)
            .combined(with: .opacity)
            .animation(motion.staggered(motion.drift, index: index))

        let leaving = AnyTransition
            .offset(y: -6)
            .combined(with: .opacity)
            .animation(motion.staggered(motion.snap, index: count - 1 - index))

        return .asymmetric(insertion: entering, removal: leaving)
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
