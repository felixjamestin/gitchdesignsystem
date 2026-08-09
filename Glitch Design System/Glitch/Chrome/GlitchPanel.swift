import SwiftUI

/// The container that makes a stack of controls read as one inspector.
public struct GlitchPanel<Content: View>: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.glitchDelight) private var delight

    private let content: Content

    @State private var hasAppeared = false

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        let metrics = theme.metrics
        let shape = RoundedRectangle(cornerRadius: metrics.panelRadius, style: .continuous)

        VStack(alignment: .leading, spacing: metrics.spacing) {
            // The panel cascades its own children on first appearance, and
            // each section cascades its rows in turn. Nesting compounds, so
            // the inner delay is deliberately the shorter of the two —
            // otherwise the last row of the last section arrives long after
            // anyone has stopped watching.
            Group(subviews: content) { children in
                ForEach(children.indices, id: \.self) { index in
                    children[index]
                        .opacity(isRevealed ? 1 : 0)
                        .offset(y: isRevealed ? 0 : 10)
                        .animation(
                            motion.staggered(motion.drift, index: delight ? index : 0),
                            value: isRevealed
                        )
                }
            }
        }
        .padding(metrics.panelPadding)
        .glitchSurface(shape, fill: theme.palette.panel)
        .overlay { shape.strokeBorder(theme.palette.stroke, lineWidth: theme.metrics.borderWidth) }
        .onAppear { hasAppeared = true }
    }

    /// With the game-feel layer off there is nothing to reveal — the panel is
    /// simply present from the first frame.
    private var isRevealed: Bool { !delight || hasAppeared }
}

/// A collapsible group, with the disclosure chevron from the second reference.
public struct GlitchSection<Content: View>: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.glitchDelight) private var delight

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

            // The condition is on each row, not on the container.
            //
            // Wrapping the whole group in `if isExpanded` makes the *group* the
            // thing being inserted, and SwiftUI then animates it as one unit —
            // the rows arrive inside an already-animating parent and their own
            // transitions never run. Two earlier attempts failed here, the
            // second by putting `.transition(.identity)` on the container,
            // which stops the fade but still doesn't hand the animation down.
            //
            // Making each row individually conditional is what actually works:
            // every row is genuinely inserted and removed on its own, so every
            // row gets its own transition, on every expand.
            VStack(alignment: .leading, spacing: theme.metrics.spacing) {
                Group(subviews: content) { rows in
                    ForEach(rows.indices, id: \.self) { index in
                        if isExpanded {
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
        // Without the game-feel layer every row shares index 0, which is the
        // same code path with every delay set to zero.
        let inIndex = delight ? index : 0
        let outIndex = delight ? count - 1 - index : 0

        let entering = AnyTransition
            .offset(y: -10)
            .combined(with: .opacity)
            .animation(motion.staggered(motion.drift, index: inIndex))

        let leaving = AnyTransition
            .offset(y: -6)
            .combined(with: .opacity)
            .animation(motion.staggered(motion.snap, index: outIndex))

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
            GlitchSound.tick()
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
