import SwiftUI

/// A radial menu, dressed in the current theme.
///
/// The mechanism underneath is `PathMenu` — a faithful SwiftUI rebuild of
/// AwesomeMenu, with its keyframe timeline, stagger and drag-to-select intact.
/// This wrapper supplies everything the design system already decides for
/// every other control, so the menu doesn't arrive with opinions of its own:
///
/// - **Surface** comes from `glitchSurface`, so a glass theme makes the petals
///   glass by the same route every other control uses. The underlying
///   component has its own glass support, deliberately left switched off — two
///   materials in one view is how a system starts disagreeing with itself.
/// - **Motion** comes from the `travel` token, expressed as spring parameters,
///   so opening a menu and switching a tab move on the same physics.
/// - **Geometry** scales with density, so the petals stay reachable on a thumb.
/// - **Sound and haptics** use the same three voices as everything else: a tick
///   as a petal takes the highlight, a commit when one is chosen.
public struct GlitchPathMenu: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.glitchDelight) private var delight
    @Environment(\.isEnabled) private var isEnabled

    private let items: [PathMenuItem]
    private let systemImage: String
    private let onSelect: (PathMenuItem) -> Void

    @State private var isExpanded = false

    public init(
        items: [PathMenuItem],
        systemImage: String = "plus",
        onSelect: @escaping (PathMenuItem) -> Void
    ) {
        self.items = items
        self.systemImage = systemImage
        self.onSelect = onSelect
    }

    public var body: some View {
        PathMenu(
            items: items,
            style: resolvedStyle,
            isExpanded: expansion,
            onSelect: { item in
                GlitchHaptics.impact()
                GlitchSound.commit()
                onSelect(item)
            },
            trigger: { phase in trigger(phase) },
            item: { item, phase in petal(item, phase) }
        )
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel("Menu")
    }

    // MARK: - Style

    private var resolvedStyle: PathMenuStyle {
        var style = PathMenuStyle()
        let metrics = theme.metrics

        // Sized off the row height, so the whole menu grows with density
        // rather than staying pointer-sized on a touch screen.
        let unit = metrics.rowHeight
        style.petalDiameter = unit * 1.25
        style.triggerDiameter = unit * 1.55
        style.endRadius = unit * 3.3
        style.nearRadius = style.endRadius * 0.92
        style.farRadius = style.endRadius * 1.17

        style.motion = .spring(
            response: motion.travelSpring.response,
            dampingRatio: motion.travelSpring.dampingRatio
        )
        style.stagger = motion.staggerDelay

        // Our own material path draws the petals, so the component's glass is
        // left off; enabling both would put glass on glass.
        style.surface = .solid
        style.hapticsEnabled = true
        style.highlightsOnHover = true
        style.dragToSelect = true
        // The blow-up is a flourish, and flourishes are what the delight
        // switch governs.
        style.selectionEffect = delight ? .blowUp : .close
        style.rotatesPetals = delight

        return style
    }

    /// Plays the open and close through the system's own voice, which the
    /// component has no way to do for us.
    private var expansion: Binding<Bool> {
        Binding(
            get: { isExpanded },
            set: { open in
                guard open != isExpanded else { return }
                isExpanded = open
                GlitchSound.tick()
            }
        )
    }

    // MARK: - Views

    private func trigger(_ phase: PathMenuTriggerPhase) -> some View {
        let diameter = theme.metrics.rowHeight * 1.55

        return Color.clear
            .glitchSurface(Circle(), fill: phase.isExpanded
                ? theme.palette.selectionFill
                : theme.palette.trackActive)
            .frame(width: diameter, height: diameter)
            .overlay {
                Circle().strokeBorder(
                    theme.metrics.tracksAreOutlined ? theme.palette.stroke : .clear,
                    lineWidth: theme.metrics.borderWidth
                )
            }
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: theme.metrics.iconSize * 1.3, weight: .semibold))
                    .foregroundStyle(phase.isExpanded
                        ? theme.palette.onSelection
                        : theme.palette.label)
            }
            .clipShape(Circle())
    }

    private func petal(_ item: PathMenuItem, _ phase: PathMenuItemPhase) -> some View {
        let diameter = theme.metrics.rowHeight * 1.25

        return Color.clear
            .glitchSurface(Circle(), fill: phase.isHighlighted
                ? theme.palette.selectionFill
                : theme.palette.trackActive)
            .frame(width: diameter, height: diameter)
            .overlay {
                Circle().strokeBorder(
                    theme.metrics.tracksAreOutlined ? theme.palette.stroke : .clear,
                    lineWidth: theme.metrics.borderWidth
                )
            }
            .overlay {
                Image(systemName: item.systemImage)
                    .font(.system(size: theme.metrics.iconSize, weight: .semibold))
                    .foregroundStyle(phase.isHighlighted
                        ? theme.palette.onSelection
                        : theme.palette.label)
            }
            .clipShape(Circle())
            .scaleEffect(phase.isHighlighted ? 1.14 : 1)
            .animation(motion.pop, value: phase.isHighlighted)
            // The same tick a segmented control makes as the selection moves,
            // for the same reason: something under the finger changed.
            .onChange(of: phase.isHighlighted) { _, highlighted in
                if highlighted { GlitchSound.tick() }
            }
            .accessibilityLabel(item.title)
    }
}

#Preview("Path menu") {
    GlitchPathMenu(
        items: [
            PathMenuItem(title: "Flow", systemImage: "wind"),
            PathMenuItem(title: "Echo", systemImage: "waveform.path.ecg"),
            PathMenuItem(title: "Noise", systemImage: "aqi.medium"),
            PathMenuItem(title: "Warp", systemImage: "tornado"),
            PathMenuItem(title: "Trim", systemImage: "scissors"),
        ],
        onSelect: { _ in }
    )
    .frame(width: 420, height: 420)
    .background(GlitchPalette.dark.background)
    .glitchTheme()
    .preferredColorScheme(.dark)
}
