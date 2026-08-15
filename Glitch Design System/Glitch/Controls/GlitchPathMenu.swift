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
/// Which rendering the themed menu uses.
public enum GlitchPathMenuVariant: Hashable, Sendable {
    /// Discrete petals on the theme's surface — glass where the theme says so.
    case standard
    /// Petals joined to the trigger by a liquid membrane while they travel.
    /// The liquid is a solid shader-drawn fill: Liquid Glass petals cannot
    /// melt into one another, so glass does not apply to this variant.
    case gooey
}

/// The gooey variant's own knobs.
public struct GlitchGooMenuStyle: Sendable {
    /// Blend range of the liquid union, in points.
    public var goo: CGFloat = 18
    /// Extra edge softness in points. Zero is a crisp antialiased edge.
    public var edgeSoftness: CGFloat = 0
    /// Fill of the liquid. `nil` uses the palette's active track.
    public var tint: Color? = nil

    public init() {}
}

public struct GlitchPathMenu: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.glitchDelight) private var delight
    @Environment(\.isEnabled) private var isEnabled

    private let items: [PathMenuItem]
    private let systemImage: String
    private let variant: GlitchPathMenuVariant
    private let gooStyle: GlitchGooMenuStyle
    private let configure: ((inout PathMenuStyle) -> Void)?
    private let onSelect: (PathMenuItem) -> Void

    @State private var isExpanded = false
    /// Which petal the liquid should swell under. Fed by the petal builder's
    /// highlight callback, the one place highlight state surfaces.
    @State private var highlightedIndex: Int?

    public init(
        items: [PathMenuItem],
        systemImage: String = "plus",
        variant: GlitchPathMenuVariant = .standard,
        gooStyle: GlitchGooMenuStyle = .init(),
        configure: ((inout PathMenuStyle) -> Void)? = nil,
        onSelect: @escaping (PathMenuItem) -> Void
    ) {
        self.items = items
        self.systemImage = systemImage
        self.variant = variant
        self.gooStyle = gooStyle
        self.configure = configure
        self.onSelect = onSelect
    }

    public var body: some View {
        let style = resolvedStyle

        PathMenu(
            items: items,
            style: style,
            isExpanded: expansion,
            onSelect: { item in
                GlitchHaptics.impact()
                GlitchSound.commit()
                onSelect(item)
            },
            trigger: { phase in trigger(phase) },
            item: { item, phase in petal(item, phase) }
        )
        .background(alignment: .center) {
            if variant == .gooey {
                gooUnderlay(style: style)
            }
        }
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel("Menu")
    }

    private func gooUnderlay(style: PathMenuStyle) -> some View {
        let geometry = PathMenuGeometry(
            count: items.count,
            nearRadius: style.nearRadius,
            endRadius: style.endRadius,
            farRadius: style.farRadius,
            wholeAngle: style.wholeAngle.radians,
            rotationOffset: style.rotationOffset.radians
        )
        let spring = style.motion.springParameters.map {
            Spring(response: $0.response, dampingRatio: $0.dampingRatio)
        } ?? motion.travelSpring

        return GooMenuUnderlay(
            count: items.count,
            anchors: geometry.anchors.map(\.end),
            triggerRadius: style.triggerDiameter / 2,
            petalRadius: style.petalDiameter / 2,
            spring: spring,
            duration: style.duration,
            stagger: style.stagger,
            isOpen: isExpanded,
            highlightedIndex: highlightedIndex,
            smoothing: gooStyle.goo,
            edge: gooStyle.edgeSoftness,
            fill: gooStyle.tint ?? theme.palette.trackActive,
            // A loosely damped spring can overshoot past farRadius, and a
            // blob crossing the canvas edge would render a flat clipped side.
            extent: 2 * (max(style.farRadius, style.endRadius * 1.4)
                + style.petalDiameter / 2 + gooStyle.goo + 8)
        )
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

        if variant == .gooey {
            // The membrane needs an analytic spring to mirror, and the blow-up
            // flourish would tear it, so the gooey menu closes plainly.
            style.motion = .spring(
                response: motion.travelSpring.response,
                dampingRatio: motion.travelSpring.dampingRatio
            )
            style.selectionEffect = .close
            style.rotatesPetals = false
        }
        configure?(&style)

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
            .glitchSurface(Circle(), fill: variant == .gooey
                ? Color.clear
                : phase.isExpanded ? theme.palette.selectionFill : theme.palette.trackActive)
            .frame(width: diameter, height: diameter)
            // The theme's fills are translucent, and the petals fly home
            // *underneath* this button — without an opaque backing they show
            // through it, stacking into a pile of overlapping discs. The
            // gooey variant needs no backing: the liquid is the button.
            .background {
                if variant == .standard {
                    Circle().fill(theme.palette.background)
                }
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
            .glitchSurface(Circle(), fill: variant == .gooey
                ? Color.clear
                : phase.isHighlighted ? theme.palette.selectionFill : theme.palette.trackActive)
            .frame(width: diameter, height: diameter)
            .overlay {
                Image(systemName: item.systemImage)
                    .font(.system(size: theme.metrics.iconSize, weight: .semibold))
                    .foregroundStyle(phase.isHighlighted
                        ? theme.palette.onSelection
                        : theme.palette.label)
                    // Returning petals converge on the centre, and on the
                    // theme's translucent surfaces they show through one
                    // another — a pile of overlapping glyphs. Every icon
                    // dissolves the moment the close begins; the discs (or
                    // the liquid, in the gooey variant) travel home alone.
                    .opacity(phase.isExpanded ? 1 : 0)
                    .animation(motion.snap, value: phase.isExpanded)
            }
            .clipShape(Circle())
            // With the gooey variant's clear fill the petal would otherwise
            // lose its hit area — the liquid beneath it takes no hits.
            .contentShape(Circle())
            .scaleEffect(phase.isHighlighted ? 1.14 : 1)
            .animation(motion.pop, value: phase.isHighlighted)
            // The same tick a segmented control makes as the selection moves,
            // for the same reason: something under the finger changed.
            .onChange(of: phase.isHighlighted) { _, highlighted in
                if highlighted {
                    GlitchSound.tick()
                    highlightedIndex = phase.index
                } else if highlightedIndex == phase.index {
                    highlightedIndex = nil
                }
            }
            .accessibilityLabel(item.title)
    }
}

#Preview("Gooey path menu") {
    GlitchPathMenu(
        items: [
            PathMenuItem(title: "Flow", systemImage: "wind"),
            PathMenuItem(title: "Echo", systemImage: "waveform.path.ecg"),
            PathMenuItem(title: "Noise", systemImage: "aqi.medium"),
            PathMenuItem(title: "Warp", systemImage: "tornado"),
        ],
        variant: .gooey,
        onSelect: { _ in }
    )
    .frame(width: 420, height: 420)
    .background(GlitchPalette.dark.background)
    .glitchTheme()
    .preferredColorScheme(.dark)
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
