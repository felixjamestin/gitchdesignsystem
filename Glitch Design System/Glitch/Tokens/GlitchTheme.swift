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
    var colors: GlitchColors
    var density: GlitchDensity?

    func body(content: Content) -> some View {
        // Overrides layer on top of the resolved palette rather than replacing
        // it, so a caller who changes one colour keeps the other nineteen —
        // and keeps them responding to light and dark.
        let palette = colors.applied(to: style.palette(colorScheme))
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
    /// style, colours or density.
    ///
    /// ```swift
    /// ContentView()
    ///     .glitchTheme()                                      // defaults
    ///     .glitchTheme(.engineering, density: .comfortable)   // a style
    ///     .glitchTheme(colors: GlitchColors(accent: .mint))   // one colour
    /// ```
    public func glitchTheme(
        _ style: GlitchThemeStyle = .glitch,
        glass: GlitchGlassVariant = .regular,
        colors: GlitchColors = .none,
        density: GlitchDensity? = nil
    ) -> some View {
        modifier(
            GlitchThemeModifier(style: style, glass: glass, colors: colors, density: density)
        )
    }
}
