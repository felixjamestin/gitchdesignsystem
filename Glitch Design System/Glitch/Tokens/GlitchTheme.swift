import SwiftUI

/// Everything a control needs to draw itself: colours, dimensions and voice.
public struct GlitchTheme: Equatable, Sendable {
    public var style: GlitchThemeStyle
    public var palette: GlitchPalette
    public var metrics: GlitchMetrics
    public var typography: GlitchTypography
    /// Whether surfaces are filled or made of glass.
    public var surface: GlitchSurface

    /// Used when a control is rendered outside a `.glitchTheme()` subtree —
    /// a bare Preview, for instance. Controls stay legible instead of blank.
    public static let fallback = GlitchTheme(
        style: .glitch,
        palette: .dark,
        metrics: .resolve(.compact, style: .glitch),
        typography: GlitchThemeStyle.glitch.typography,
        surface: .solid
    )

    /// A label as this style writes it.
    public func display(_ text: String) -> String {
        typography.uppercaseLabels ? text.uppercased() : text
    }
}

extension EnvironmentValues {
    @Entry public var glitchTheme: GlitchTheme = .fallback
    @Entry public var glitchDensity: GlitchDensity = .platformDefault
    @Entry public var glitchThemeStyle: GlitchThemeStyle = .glitch
}

private struct GlitchThemeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    var style: GlitchThemeStyle
    var glass: GlitchGlassVariant
    var accent: Color?
    var density: GlitchDensity?

    func body(content: Content) -> some View {
        var palette = style.palette(colorScheme)
        if let accent {
            palette.accent = accent
        }
        let density = density ?? .platformDefault

        return content
            .environment(
                \.glitchTheme,
                GlitchTheme(
                    style: style,
                    palette: palette,
                    metrics: .resolve(density, style: style),
                    typography: style.typography,
                    surface: style.surface(glass: glass)
                )
            )
            .environment(\.glitchDensity, density)
            .environment(\.glitchThemeStyle, style)
            .tint(palette.accent)
    }
}

extension View {
    /// Installs a style, palette and metrics for this subtree.
    ///
    /// Apply once at the root — or again lower down to give a section its own
    /// style, accent or density.
    public func glitchTheme(
        _ style: GlitchThemeStyle = .glitch,
        glass: GlitchGlassVariant = .regular,
        accent: Color? = nil,
        density: GlitchDensity? = nil
    ) -> some View {
        modifier(
            GlitchThemeModifier(style: style, glass: glass, accent: accent, density: density)
        )
    }
}
