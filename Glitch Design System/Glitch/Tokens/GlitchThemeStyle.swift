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
    public var surface: GlitchSurface {
        self == .liquidGlass ? .glass : .solid
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
            // Tight, machined radii rather than soft ones.
            metrics.controlRadius = round(metrics.controlRadius * 0.5)
            metrics.panelRadius = round(metrics.panelRadius * 0.6)
            metrics.borderWidth = 1
            metrics.tracksAreOutlined = true

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
            GlitchTypography(
                labelDesign: .default,
                valueDesign: .monospaced,
                labelWeight: .semibold,
                valueWeight: .semibold,
                titleWeight: .bold,
                tracking: 0.8,
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

    /// OP-1 in daylight: warm grey body, black legends, one orange.
    private static let engineeringLight = GlitchPalette(
        background: Color(glitchHex: 0xD6D6D2),
        panel: Color(glitchHex: 0xEDEDE9),
        track: .black.opacity(0.07),
        trackHover: .black.opacity(0.11),
        trackActive: .black.opacity(0.14),
        fill: Color(glitchHex: 0xFF4F00).opacity(0.22),
        fillActive: Color(glitchHex: 0xFF4F00).opacity(0.34),
        handle: Color(glitchHex: 0xFF4F00),
        hashmark: .black.opacity(0.28),
        textPrimary: .black.opacity(0.92),
        label: .black.opacity(0.72),
        labelSecondary: .black.opacity(0.45),
        stroke: .black.opacity(0.18),
        strokeHover: .black.opacity(0.30),
        accent: Color(glitchHex: 0xFF4F00),
        onAccent: .white,
        danger: Color(glitchHex: 0xD1293D)
    )

    /// The black-chassis variant of the same instrument.
    private static let engineeringDark = GlitchPalette(
        background: Color(glitchHex: 0x121212),
        panel: Color(glitchHex: 0x1E1E1E),
        track: .white.opacity(0.07),
        trackHover: .white.opacity(0.12),
        trackActive: .white.opacity(0.15),
        fill: Color(glitchHex: 0xFF4F00).opacity(0.32),
        fillActive: Color(glitchHex: 0xFF4F00).opacity(0.48),
        handle: Color(glitchHex: 0xFF6A24),
        hashmark: .white.opacity(0.26),
        textPrimary: .white.opacity(0.95),
        label: .white.opacity(0.72),
        labelSecondary: .white.opacity(0.45),
        stroke: .white.opacity(0.16),
        strokeHover: .white.opacity(0.28),
        accent: Color(glitchHex: 0xFF6A24),
        onAccent: Color(glitchHex: 0x121212),
        danger: Color(glitchHex: 0xFF5C69)
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
