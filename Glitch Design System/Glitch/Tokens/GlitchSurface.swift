import SwiftUI

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
    case glass
}

private struct GlitchSurfaceModifier<S: Shape>: ViewModifier {
    @Environment(\.glitchTheme) private var theme

    let shape: S
    let fill: Color

    func body(content: Content) -> some View {
        switch theme.surface {
        case .solid:
            content.background(shape.fill(fill))
        case .glass:
            content.glassEffect(.regular.tint(fill), in: shape)
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
