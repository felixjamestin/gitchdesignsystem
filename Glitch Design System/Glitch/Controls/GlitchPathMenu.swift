import SwiftUI

/// A radial menu, dressed in the current theme.
///
/// The mechanism underneath is `PathMenu` — a faithful SwiftUI rebuild of
/// AwesomeMenu, with its keyframe timeline, stagger and drag-to-select intact.
/// This wrapper supplies everything the design system already decides for
/// every other control, so the menu doesn't arrive with opinions of its own:
///
/// - **Surface** is explicit. Solid, native Liquid Glass, and merged Goo stay
///   distinct, so a lab control always changes the material it names.
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

    @Environment(\.glitchGooStyle) private var gooStyle

    private let items: [PathMenuItem]
    private let systemImage: String
    private let surface: PathMenuSurface
    private let spread: CGFloat
    private let wholeAngle: Angle
    private let rotationOffset: Angle
    private let petalScale: CGFloat
    private let triggerScale: CGFloat
    private let staggerScale: Double
    private let bondsTrigger: Bool
    private let glassBlendSpacing: CGFloat
    private let onSelect: (PathMenuItem) -> Void

    @State private var isExpanded = false

    public init(
        items: [PathMenuItem],
        systemImage: String = "plus",
        surface: PathMenuSurface = .solid,
        spread: CGFloat = 1,
        wholeAngle: Angle = .degrees(360),
        rotationOffset: Angle = .zero,
        petalScale: CGFloat = 1,
        triggerScale: CGFloat = 1,
        staggerScale: Double = 1,
        bondsTrigger: Bool = true,
        glassBlendSpacing: CGFloat = 0,
        onSelect: @escaping (PathMenuItem) -> Void
    ) {
        self.items = items
        self.systemImage = systemImage
        self.surface = surface
        self.spread = spread
        self.wholeAngle = wholeAngle
        self.rotationOffset = rotationOffset
        self.petalScale = petalScale
        self.triggerScale = triggerScale
        self.staggerScale = staggerScale
        self.bondsTrigger = bondsTrigger
        self.glassBlendSpacing = glassBlendSpacing
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
    }

    // MARK: - Style

    private var resolvedStyle: PathMenuStyle {
        var style = PathMenuStyle()
        let metrics = theme.metrics
        let resolvedPetalScale = min(max(petalScale, 0.6), 1.8)
        let resolvedTriggerScale = min(max(triggerScale, 0.6), 1.8)

        // Sized off the row height, so the whole menu grows with density
        // rather than staying pointer-sized on a touch screen.
        let unit = metrics.rowHeight
        style.petalDiameter = unit * 1.25 * resolvedPetalScale
        style.triggerDiameter = unit * 1.55 * resolvedTriggerScale
        // How far the petals travel. Drawn close, they stay bonded to the trigger
        // and to each other on a gooey surface even at rest; drawn far, the
        // bridges form and break during the travel and the menu settles as
        // separate discs. Both are worth having, so it is a parameter.
        style.endRadius = unit * 3.3 * spread
        style.nearRadius = style.endRadius * 0.92
        style.farRadius = style.endRadius * 1.17
        style.wholeAngle = wholeAngle
        style.rotationOffset = rotationOffset

        style.motion = .spring(
            response: motion.travelSpring.response,
            dampingRatio: motion.travelSpring.dampingRatio
        )
        style.stagger = motion.staggerDelay * min(max(staggerScale, 0), 3)

        style.surface = resolvedSurface
        style.glassBlendSpacing = min(max(glassBlendSpacing, 0), 96)
        style.goo = gooStyle
        if style.goo.fill == nil {
            style.goo.fill = theme.palette.trackActive
        }
        style.bondsTrigger = bondsTrigger
        style.hapticsEnabled = true
        style.highlightsOnHover = true
        style.dragToSelect = true
        // The blow-up is a flourish, and flourishes are what the delight
        // switch governs.
        // The Goo body is one surface. It must remain present while the petals
        // travel home, so it uses the normal close path.
        style.selectionEffect = delight && resolvedSurface != .gooey ? .blowUp : .close
        style.rotatesPetals = delight

        return style
    }

    private var resolvedSurface: PathMenuSurface {
        surface == .gooey && !delight ? .solid : surface
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
        menuDisc(
            systemImage: systemImage,
            diameter: theme.metrics.rowHeight * 1.55 * min(max(triggerScale, 0.6), 1.8),
            iconSize: theme.metrics.iconSize * 1.3,
            fill: phase.isExpanded ? theme.palette.selectionFill : theme.palette.trackActive,
            foreground: phase.isExpanded ? theme.palette.onSelection : theme.palette.label
        )
    }

    private func petal(_ item: PathMenuItem, _ phase: PathMenuItemPhase) -> some View {
        menuDisc(
            systemImage: item.systemImage,
            diameter: theme.metrics.rowHeight * 1.25 * min(max(petalScale, 0.6), 1.8),
            iconSize: theme.metrics.iconSize,
            fill: phase.isHighlighted ? theme.palette.selectionFill : theme.palette.trackActive,
            foreground: phase.isHighlighted ? theme.palette.onSelection : theme.palette.label
        )
            .scaleEffect(phase.isHighlighted ? 1.14 : 1)
            .animation(motion.pop, value: phase.isHighlighted)
            // The same tick a segmented control makes as the selection moves,
            // for the same reason: something under the finger changed.
            .onChange(of: phase.isHighlighted) { _, highlighted in
                if highlighted { GlitchSound.tick() }
            }
            .accessibilityLabel(item.title)
    }

    @ViewBuilder
    private func menuDisc(
        systemImage: String,
        diameter: CGFloat,
        iconSize: CGFloat,
        fill: Color,
        foreground: Color
    ) -> some View {
        #if os(visionOS)
        if resolvedSurface == .gooey {
            menuSymbol(systemImage, diameter: diameter, iconSize: iconSize, foreground: foreground)
        } else {
            solidDisc(systemImage, diameter: diameter, iconSize: iconSize,
                      fill: fill, foreground: foreground)
        }
        #else
        if resolvedSurface == .gooey {
            // `PathMenu` draws the one merged surface below this symbol.
            menuSymbol(systemImage, diameter: diameter, iconSize: iconSize, foreground: foreground)
        } else if #available(iOS 26.0, macOS 26.0, *), resolvedSurface.isGlass {
            menuSymbol(systemImage, diameter: diameter, iconSize: iconSize, foreground: foreground)
                .glassEffect(glass(fill: fill), in: .circle)
        } else {
            solidDisc(systemImage, diameter: diameter, iconSize: iconSize,
                      fill: fill, foreground: foreground)
        }
        #endif
    }

    private func solidDisc(
        _ systemImage: String,
        diameter: CGFloat,
        iconSize: CGFloat,
        fill: Color,
        foreground: Color
    ) -> some View {
        Circle()
            .fill(fill)
            .frame(width: diameter, height: diameter)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(foreground)
            }
    }

    private func menuSymbol(
        _ systemImage: String,
        diameter: CGFloat,
        iconSize: CGFloat,
        foreground: Color
    ) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
    }

    #if !os(visionOS)
    @available(iOS 26.0, macOS 26.0, *)
    private func glass(fill: Color) -> Glass {
        let base: Glass = resolvedSurface == .clearGlass ? .clear : .regular
        return base.tint(fill.opacity(0.62))
    }
    #endif
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
