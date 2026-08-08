import SwiftUI

/// The system's visual voices.
///
/// A style changes colour, corner radius, border weight and typography — but
/// never behaviour. A slider drags, snaps and stretches identically in all
/// three; only its appearance is up for negotiation. That separation is the
/// point of having styles at all: switching one must never be a functional
/// change.
public enum GlitchThemeStyle: String, CaseIterable, Sendable, Hashable {
    /// The default. Neutral white alphas over near-black, sentence case,
    /// softly rounded — the inspector-panel voice.
    case glitch
    /// Teenage Engineering: light body, black text, one hot orange doing all
    /// the signalling, tight radii, uppercase micro-labels. Instrument-like.
    case engineering
    /// VSCO: near-total absence. No containers, no borders, no fills — a
    /// hairline, a dot, and a great deal of white space.
    case film
    /// Liquid glass: the platform material, generous radii, and a palette of
    /// tints rather than fills — every surface refracts what is behind it.
    case liquidGlass

    public var title: String {
        switch self {
        case .glitch: "Glitch"
        case .engineering: "Engineering"
        case .film: "Film"
        case .liquidGlass: "Glass"
        }
    }

    /// Glass is the only style whose surfaces are a material rather than a
    /// colour. Everything else in the system is unaware of the distinction.
    public func surface(glass variant: GlitchGlassVariant) -> GlitchSurface {
        self == .liquidGlass ? .glass(variant) : .solid
    }

    // MARK: - Colour

    public func palette(_ scheme: ColorScheme) -> GlitchPalette {
        switch self {
        case .glitch:
            return GlitchPalette.resolve(scheme)
        case .engineering:
            return scheme == .dark ? Self.engineeringDark : Self.engineeringLight
        case .film:
            return scheme == .dark ? Self.filmDark : Self.filmLight
        case .liquidGlass:
            return scheme == .dark ? Self.glassDark : Self.glassLight
        }
    }

    // MARK: - Geometry

    /// Applied on top of the density's metrics, so both dimensions stay
    /// independent: any style works at any density.
    public func adjust(_ metrics: inout GlitchMetrics) {
        switch self {
        case .glitch:
            break

        case .engineering:
            // Almost no radius: these are parts milled into a chassis, not
            // cards floating on a page.
            metrics.controlRadius = 2
            metrics.panelRadius = 3
            metrics.borderWidth = 1
            metrics.tracksAreOutlined = true
            // The scale is printed on the panel, not summoned by touching it.
            metrics.hashmarksAlwaysVisible = true
            metrics.hashmarkHeight = metrics.rowHeight * 0.55
            // Legends are engraved small and spaced wide.
            metrics.labelSize = max(9, metrics.labelSize - 3)
            metrics.handleWidth = max(2, metrics.handleWidth - 1)
            metrics.handleHeight = metrics.rowHeight - 8
            metrics.handleInset = 0

        case .film:
            // Nothing is a container. The panel has no edge, controls have no
            // wells, and separation is done with space rather than with lines.
            metrics.controlRadius = 2
            metrics.panelRadius = 0
            metrics.borderWidth = 0
            metrics.tracksAreOutlined = false
            metrics.panelPadding = metrics.panelPadding * 1.6
            metrics.spacing = metrics.spacing * 2.2
            metrics.labelSize = max(9, metrics.labelSize - 3)

            // The slider keeps the same solid bar every other control has.
            // An earlier version drew it as a hairline with the legend above,
            // which was more faithful to the app it borrows from but made the
            // one control that matters look unrelated to the rest of the
            // panel. Consistency inside a theme beats fidelity to its
            // inspiration.
            metrics.handleAlwaysVisible = true
            metrics.hashmarkHeight = 6

        case .liquidGlass:
            // Glass reads as a lens, and a lens with tight corners looks like
            // a chip of it. The rim is what sells the thickness.
            metrics.controlRadius = round(metrics.rowHeight / 2)
            metrics.panelRadius = round(metrics.panelRadius * 1.6)
            metrics.borderWidth = 1
            metrics.tracksAreOutlined = true
        }
    }

    // MARK: - Type

    public var typography: GlitchTypography {
        switch self {
        case .glitch:
            GlitchTypography(
                labelDesign: .default,
                valueDesign: .monospaced,
                labelWeight: .medium,
                valueWeight: .medium,
                titleWeight: .semibold,
                tracking: 0,
                uppercaseLabels: false
            )
        case .engineering:
            // Engraved legends: small, heavy, and spaced far enough apart to
            // read as printing rather than as text.
            GlitchTypography(
                labelDesign: .default,
                valueDesign: .monospaced,
                labelWeight: .bold,
                valueWeight: .bold,
                titleWeight: .black,
                tracking: 1.6,
                uppercaseLabels: true
            )
        case .film:
            // Small, light, and spaced far apart. The type is a caption on a
            // photograph, not a control label.
            GlitchTypography(
                labelDesign: .default,
                valueDesign: .default,
                labelWeight: .regular,
                valueWeight: .regular,
                titleWeight: .medium,
                tracking: 1.8,
                uppercaseLabels: true
            )
        case .liquidGlass:
            // Slightly heavier than the default: text over a refracting
            // surface needs more weight to hold its edge.
            GlitchTypography(
                labelDesign: .rounded,
                valueDesign: .monospaced,
                labelWeight: .semibold,
                valueWeight: .semibold,
                titleWeight: .bold,
                tracking: 0,
                uppercaseLabels: false
            )
        }
    }

    // MARK: - Palettes

    /// A device, not a document.
    ///
    /// The first attempt at this was a light panel with a tinted fill, which
    /// was just the default style in beige. What actually reads as Teenage
    /// Engineering is the *construction*: an unpainted chassis with parts let
    /// into it, scales printed directly onto the surface, legends engraved
    /// small and spaced wide, and colour used only where something is live.
    ///
    /// So the track is barely darker than the body — a shallow recess — while
    /// the fill is full-strength orange, the marks are always printed, and the
    /// pointer is a hard black line the full height of its slot.
    private static let engineeringLight = GlitchPalette(
        background: Color(glitchHex: 0xC9C9C4),
        panel: Color(glitchHex: 0xE4E4DF),
        track: .black.opacity(0.05),
        trackHover: .black.opacity(0.09),
        trackActive: .black.opacity(0.12),
        fill: Color(glitchHex: 0xFF5A00).opacity(0.92),
        fillActive: Color(glitchHex: 0xFF5A00),
        handle: .black.opacity(0.88),
        hashmark: .black.opacity(0.32),
        textPrimary: .black,
        label: .black.opacity(0.80),
        labelSecondary: .black.opacity(0.45),
        stroke: .black.opacity(0.35),
        strokeHover: .black.opacity(0.55),
        accent: Color(glitchHex: 0xFF5A00),
        onAccent: .black,
        danger: Color(glitchHex: 0xD1293D),
        // Selection is a printed switch: solid black, knocked-out legend.
        selectionFill: .black.opacity(0.88),
        onSelection: Color(glitchHex: 0xE4E4DF),
        // Black on full-strength orange, which is more legible than the
        // chassis-coloured legend would be.
        onFill: .black.opacity(0.88)
    )

    /// The black-chassis variant of the same instrument.
    private static let engineeringDark = GlitchPalette(
        background: Color(glitchHex: 0x0F0F0F),
        panel: Color(glitchHex: 0x1A1A1A),
        track: .white.opacity(0.05),
        trackHover: .white.opacity(0.09),
        trackActive: .white.opacity(0.12),
        fill: Color(glitchHex: 0xFF5A00).opacity(0.92),
        fillActive: Color(glitchHex: 0xFF5A00),
        handle: .white.opacity(0.92),
        hashmark: .white.opacity(0.30),
        textPrimary: .white,
        label: .white.opacity(0.80),
        labelSecondary: .white.opacity(0.45),
        stroke: .white.opacity(0.30),
        strokeHover: .white.opacity(0.50),
        accent: Color(glitchHex: 0xFF5A00),
        onAccent: .black,
        danger: Color(glitchHex: 0xFF5C69),
        selectionFill: .white.opacity(0.90),
        onSelection: Color(glitchHex: 0x1A1A1A),
        onFill: .black.opacity(0.88)
    )

    /// Almost nothing.
    ///
    /// VSCO's whole argument is that the interface should get out of the way
    /// of the image, so it removes containers entirely: no cards, no borders,
    /// no filled wells. What is left is a hairline, a dot, a very small
    /// letter-spaced caption, and a lot of paper.
    ///
    /// The palette is correspondingly thin. `track` is barely visible and
    /// `fill` is nearly black, because on a two-point line contrast is the
    /// only thing carrying the reading.
    private static let filmLight = GlitchPalette(
        background: .white,
        panel: .white,
        track: .black.opacity(0.12),
        trackHover: .black.opacity(0.16),
        trackActive: .black.opacity(0.20),
        fill: .black.opacity(0.82),
        fillActive: .black.opacity(0.92),
        handle: .black.opacity(0.88),
        hashmark: .black.opacity(0.16),
        textPrimary: .black.opacity(0.82),
        label: .black.opacity(0.42),
        labelSecondary: .black.opacity(0.30),
        stroke: .black.opacity(0.07),
        strokeHover: .black.opacity(0.12),
        accent: .black.opacity(0.82),
        onAccent: .white,
        danger: Color(glitchHex: 0xC0392B),
        selectionFill: .black.opacity(0.86),
        onSelection: .white,
        // The bar is 82% black on paper: anything under it has to go white.
        onFill: .white.opacity(0.95)
    )

    /// The darkroom. Same construction, inverted.
    private static let filmDark = GlitchPalette(
        background: Color(glitchHex: 0x0A0A0A),
        panel: Color(glitchHex: 0x0A0A0A),
        track: .white.opacity(0.16),
        trackHover: .white.opacity(0.22),
        trackActive: .white.opacity(0.28),
        fill: .white.opacity(0.86),
        fillActive: .white,
        handle: .white.opacity(0.92),
        hashmark: .white.opacity(0.18),
        textPrimary: .white.opacity(0.86),
        label: .white.opacity(0.45),
        labelSecondary: .white.opacity(0.32),
        stroke: .white.opacity(0.09),
        strokeHover: .white.opacity(0.15),
        accent: .white.opacity(0.86),
        onAccent: Color(glitchHex: 0x0A0A0A),
        danger: Color(glitchHex: 0xE74C3C),
        selectionFill: .white.opacity(0.90),
        onSelection: Color(glitchHex: 0x0A0A0A),
        onFill: .black.opacity(0.88)
    )

    private static let glassDark = GlitchPalette(
        background: Color(glitchHex: 0x0C1018),
        panel: .white.opacity(0.06),
        track: .white.opacity(0.10),
        trackHover: .white.opacity(0.16),
        trackActive: .white.opacity(0.22),
        fill: .white.opacity(0.24),
        fillActive: .white.opacity(0.36),
        handle: .white.opacity(0.95),
        hashmark: .white.opacity(0.35),
        textPrimary: .white,
        label: .white.opacity(0.85),
        labelSecondary: .white.opacity(0.60),
        stroke: .white.opacity(0.22),
        strokeHover: .white.opacity(0.34),
        accent: .white.opacity(0.95),
        onAccent: Color(glitchHex: 0x0C1018),
        danger: Color(glitchHex: 0xFF6B6B),
        onFill: .white.opacity(0.85)
    )

    private static let glassLight = GlitchPalette(
        background: Color(glitchHex: 0xE7ECF3),
        panel: .white.opacity(0.35),
        track: .white.opacity(0.45),
        trackHover: .white.opacity(0.62),
        trackActive: .white.opacity(0.78),
        fill: .black.opacity(0.10),
        fillActive: .black.opacity(0.16),
        handle: .black.opacity(0.70),
        hashmark: .black.opacity(0.25),
        textPrimary: .black.opacity(0.90),
        label: .black.opacity(0.70),
        labelSecondary: .black.opacity(0.45),
        stroke: .white.opacity(0.60),
        strokeHover: .white.opacity(0.80),
        accent: .black.opacity(0.70),
        onAccent: .white,
        danger: Color(glitchHex: 0xD1293D),
        onFill: .black.opacity(0.70)
    )

}

/// A style's typographic voice.
public struct GlitchTypography: Equatable, Sendable {
    public var labelDesign: Font.Design
    public var valueDesign: Font.Design
    public var labelWeight: Font.Weight
    public var valueWeight: Font.Weight
    public var titleWeight: Font.Weight
    public var tracking: CGFloat
    public var uppercaseLabels: Bool
}
