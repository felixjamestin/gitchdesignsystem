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
    /// A flat fill. Every style but one.
    case solid
    /// The platform's glass material, tinted by the same token a solid style
    /// would have filled with — so the two stay in step as the palette changes.
    case glass(GlitchGlassVariant)
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
