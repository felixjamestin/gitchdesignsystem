import SwiftUI

/// Everything a control needs to draw itself: colors and dimensions.
public struct GlitchTheme: Equatable, Sendable {
    public var palette: GlitchPalette
    public var metrics: GlitchMetrics

    /// Used when a control is rendered outside a `.glitchTheme()` subtree —
    /// a bare Preview, for instance. Controls stay legible instead of blank.
    public static let fallback = GlitchTheme(palette: .dark, metrics: .compact)
}

extension EnvironmentValues {
    @Entry public var glitchTheme: GlitchTheme = .fallback
    @Entry public var glitchDensity: GlitchDensity = .platformDefault
}

private struct GlitchThemeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    var accent: Color?
    var density: GlitchDensity?

    func body(content: Content) -> some View {
        var palette = GlitchPalette.resolve(colorScheme)
        if let accent { palette.accent = accent }
        let density = density ?? .platformDefault

        return content
            .environment(\.glitchTheme, GlitchTheme(palette: palette, metrics: .resolve(density)))
            .environment(\.glitchDensity, density)
            .tint(palette.accent)
    }
}

extension View {
    /// Resolves the palette from the current color scheme and installs the
    /// theme for this subtree. Apply once at the root — or again lower down to
    /// override the accent or density for a section.
    public func glitchTheme(accent: Color? = nil, density: GlitchDensity? = nil) -> some View {
        modifier(GlitchThemeModifier(accent: accent, density: density))
    }
}
