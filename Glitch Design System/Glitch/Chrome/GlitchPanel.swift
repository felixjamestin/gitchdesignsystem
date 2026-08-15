import SwiftUI

/// What a panel draws behind its contents.
public enum GlitchPanelBackground: Equatable, Sendable {
    /// The style's own surface: a fill, an edge, and glass where the style
    /// calls for it.
    case surface
    /// Nothing at all. The panel keeps its padding, spacing and staggered
    /// reveal, and contributes no appearance of its own — for a panel laid over
    /// artwork, or one grouping controls that should read as loose on the page.
    ///
    /// A distinct case rather than a clear `fill`, because a clear fill is not
    /// the same thing: under a glass style the material would still be drawn,
    /// tinted by nothing, and the panel would remain visible.
    case transparent
}

/// The container that makes a stack of controls read as one inspector.
public struct GlitchPanel<Content: View>: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.glitchDelight) private var delight

    private let background: GlitchPanelBackground
    private let content: Content

    @State private var hasAppeared = false

    public init(
        background: GlitchPanelBackground = .surface,
        @ViewBuilder content: () -> Content
    ) {
        self.background = background
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
        .modifier(GlitchPanelSurface(background: background, shape: shape))
        // Outside the sections, which clip. A tooltip opened on any row in this
        // panel is drawn here, where nothing crops it.
        .glitchTooltipLayer()
        .onAppear { hasAppeared = true }
    }

    /// With the game-feel layer off there is nothing to reveal — the panel is
    /// simply present from the first frame.
    private var isRevealed: Bool { !delight || hasAppeared }
}

/// Draws a panel's surface, or declines to draw anything.
private struct GlitchPanelSurface<S: InsettableShape>: ViewModifier {
    @Environment(\.glitchTheme) private var theme

    let background: GlitchPanelBackground
    let shape: S

    func body(content: Content) -> some View {
        switch background {
        case .surface:
            content
                .glitchSurface(shape, fill: theme.palette.panel)
                .overlay {
                    shape.strokeBorder(theme.palette.stroke, lineWidth: theme.metrics.borderWidth)
                }
        case .transparent:
            content
        }
    }
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
        // Vertical only. The clip is here to stop a collapsing row sliding out
        // from under the header, which is a vertical problem — but `.clipped()`
        // solves it on both axes, and a slider straining at a limit grows
        // *horizontally* past the row. That overhang was being cut flat, which
        // squares off the track's rounded end at the one moment the control is
        // trying to say it has run out of room.
        .clipShape(GlitchRowClip())
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
            GlitchType.titleText(title, theme)
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

/// Clips vertically and lets content overflow horizontally.
///
/// Rows in this system are free to grow sideways — a slider stretches past its
/// own edge at a limit, and a tooltip reaches beyond the label it belongs to —
/// while nothing is ever meant to escape a section vertically. One axis of
/// containment, which is what `.clipped()` cannot express.
///
/// The slack is generous rather than exact: it comes from the largest stretch
/// the system produces, doubled, so a control that overhangs a little more
/// later doesn't quietly reintroduce the flat edge this exists to prevent.
struct GlitchRowClip: Shape {
    var slack: CGFloat = CGFloat(GlitchValueMath.maximumTrackOverscroll) * 2

    func path(in rect: CGRect) -> Path {
        Path(rect.insetBy(dx: -slack, dy: 0))
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
