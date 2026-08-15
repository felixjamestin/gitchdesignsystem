import SwiftUI

/// Which glass a glass style uses.
public enum GlitchGlassVariant: String, CaseIterable, Sendable, Hashable {
    /// Frosted. Reads as a surface with things behind it.
    case regular
    /// Barely there — refraction and specular edge with almost no diffusion.
    /// Wants something worth looking at behind it, and enough contrast in the
    /// content to survive having no backing.
    case clear

    public var title: String { rawValue.capitalized }
}

/// What a control's background is made of.
///
/// Colour, radius and type can all be expressed as tokens, but a material
/// cannot — glass refracts what is behind it, so it has to be applied rather
/// than described. This is the one axis where a style changes *how* a surface
/// is drawn rather than merely what colour it is.
public enum GlitchSurface: Sendable, Hashable {
    /// A flat fill. What every style but Glass prefers.
    case solid
    /// The platform's glass material, tinted by the same token a solid style
    /// would have filled with — so the two stay in step as the palette changes.
    case glass(GlitchGlassVariant)
    /// The platform's blur material — `NSVisualEffectView` on macOS,
    /// `UIVisualEffectView` on iOS, reached through SwiftUI's `Material` —
    /// beneath the same token fill, which reads as a tint over the blur.
    case blurred
}

/// Which material surfaces are made of, chosen independently of style.
///
/// Style used to decide this on its own — glass for the Glass style, flat
/// fills for the rest. This axis unbolts the two: Engineering on glass, or
/// Glitch over a blur, without either style changing its colours or voice.
public enum GlitchMaterial: String, CaseIterable, Sendable, Hashable {
    /// Whatever the style prefers. The default, and the prior behaviour.
    case automatic
    /// Flat token fills, whatever the style.
    case solid
    /// Liquid Glass, whatever the style.
    case glass
    /// The platform's blur material, whatever the style.
    case blurred

    public var title: String {
        switch self {
        case .automatic: "Auto"
        case .solid: "Solid"
        case .glass: "Glass"
        case .blurred: "Blur"
        }
    }

    func surface(style: GlitchThemeStyle, glass variant: GlitchGlassVariant) -> GlitchSurface {
        switch self {
        case .automatic: style.surface(glass: variant)
        case .solid: .solid
        case .glass: .glass(variant)
        case .blurred: .blurred
        }
    }
}

private struct GlitchSurfaceModifier<S: Shape>: ViewModifier {
    @Environment(\.glitchTheme) private var theme

    let shape: S
    let fill: Color

    func body(content: Content) -> some View {
        switch theme.surface {
        case .solid:
            content.background(shape.fill(fill))
        case .glass(.regular):
            content.glassEffect(.regular.tint(fill), in: shape)
        case .glass(.clear):
            content.glassEffect(.clear.tint(fill), in: shape)
        case .blurred:
            content.background {
                shape.fill(.thinMaterial)
                    .overlay(shape.fill(fill))
            }
        }
    }
}

extension View {
    /// Fills this view's background with the current style's surface material.
    ///
    /// Call sites pass the colour they would have used anyway; a glass style
    /// reinterprets it as a tint. Nothing at the call site knows which it got.
    public func glitchSurface(_ shape: some Shape, fill: Color) -> some View {
        modifier(GlitchSurfaceModifier(shape: shape, fill: fill))
    }
}
