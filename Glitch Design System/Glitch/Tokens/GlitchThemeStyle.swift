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
    /// Brutalist: no radii anywhere, hard two-point borders, monospaced
    /// uppercase throughout, and no soft fills. Structure left showing.
    case brutalist
    /// Liquid glass: the platform material, generous radii, and a palette of
    /// tints rather than fills — every surface refracts what is behind it.
    case liquidGlass

    public var title: String {
        switch self {
        case .glitch: "Glitch"
        case .engineering: "Engineering"
        case .brutalist: "Brutalist"
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
        case .brutalist:
            return scheme == .dark ? Self.brutalistDark : Self.brutalistLight
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

        case .brutalist:
            metrics.controlRadius = 0
            metrics.panelRadius = 0
            metrics.borderWidth = 2
            metrics.tracksAreOutlined = true
            metrics.sharpEdges = true

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
        case .brutalist:
            GlitchTypography(
                labelDesign: .monospaced,
                valueDesign: .monospaced,
                labelWeight: .bold,
                valueWeight: .bold,
                titleWeight: .black,
                tracking: 0.5,
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
        onSelection: Color(glitchHex: 0xE4E4DF)
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
        onSelection: Color(glitchHex: 0x1A1A1A)
    )

    /// Paper and ink. The border does the work that colour does elsewhere.
    private static let brutalistLight = GlitchPalette(
        background: .white,
        panel: .white,
        track: .black.opacity(0.05),
        trackHover: .black.opacity(0.10),
        trackActive: .black.opacity(0.14),
        fill: .black.opacity(0.18),
        fillActive: .black.opacity(0.28),
        handle: .black,
        hashmark: .black.opacity(0.40),
        textPrimary: .black,
        label: .black.opacity(0.85),
        labelSecondary: .black.opacity(0.55),
        stroke: .black,
        strokeHover: .black,
        accent: Color(glitchHex: 0xFF2D00),
        onAccent: .white,
        danger: Color(glitchHex: 0xFF2D00)
    )

    /// Tints, not fills. Each value is what the glass is *coloured* by, so the
    /// alphas are lower than a solid style's — the material supplies the rest.
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
        danger: Color(glitchHex: 0xFF6B6B)
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
        danger: Color(glitchHex: 0xD1293D)
    )

    private static let brutalistDark = GlitchPalette(
        background: .black,
        panel: .black,
        track: .white.opacity(0.08),
        trackHover: .white.opacity(0.13),
        trackActive: .white.opacity(0.18),
        fill: .white.opacity(0.20),
        fillActive: .white.opacity(0.32),
        handle: .white,
        hashmark: .white.opacity(0.45),
        textPrimary: .white,
        label: .white.opacity(0.85),
        labelSecondary: .white.opacity(0.55),
        stroke: .white,
        strokeHover: .white,
        accent: Color(glitchHex: 0xFF3D14),
        onAccent: .black,
        danger: Color(glitchHex: 0xFF3D14)
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
