import SwiftUI

/// How tooltips are drawn, independent of the theme they sit in.
///
/// Its own style rather than more fields on `GlitchTheme` because a tooltip is
/// the one surface in the system that is never *part* of the layout: it is
/// briefly over the top of it, usually over content it did not choose, and the
/// treatment that makes it readable there is not the treatment that makes a
/// control readable in place. Keeping it separate means restyling tooltips
/// cannot disturb anything else, and picking a theme cannot silently restyle
/// tooltips.
///
/// The background is a `GlitchSurface`, the same vocabulary controls use, so
/// "clear glass" means here exactly what it means everywhere else — and a
/// surface added there arrives here for free.
///
/// ```swift
/// .glitchTooltipStyle(GlitchTooltipStyle(surface: .solid, fill: .black, fillOpacity: 0.8))
/// .glitchTooltipStyle(GlitchTooltipStyle(size: 13, tracking: 0, stroke: .white.opacity(0.15)))
/// ```
/// The outline a tooltip is cut to.
public enum GlitchTooltipShape: String, CaseIterable, Sendable, Hashable {
    /// Hard corners. Reads as a label rather than a bubble.
    case rectangle
    /// The theme's control radius, matching the parts underneath it.
    case roundedRectangle
    /// Fully round ends. Wants a single line of text — a pill that wraps to
    /// three lines has a lot of empty corner.
    case pill
    /// A scalloped bubble, re-rolled on every appearance. See
    /// `GlitchThoughtCloud`.
    case thoughtCloud

    public var title: String {
        switch self {
        case .rectangle: "Rectangle"
        case .roundedRectangle: "Rounded"
        case .pill: "Pill"
        case .thoughtCloud: "Thought cloud"
        }
    }
}

public struct GlitchTooltipStyle: Equatable, Sendable {
    /// The outline. `thoughtCloud` takes a new set of lobes each time a
    /// tooltip appears; the rest are fixed.
    public var shape: GlitchTooltipShape

    /// What the bubble is made of: a flat fill, either glass, or the
    /// platform's blur material.
    public var surface: GlitchSurface

    /// The fill, read differently by each surface: the colour itself when
    /// solid, a tint when glass or blurred. `nil` leaves glass untinted — which
    /// is the whole point of clear glass — and falls back to the theme's panel
    /// colour for a solid fill, which has to be *some* colour to exist.
    public var fill: Color?

    /// Applied to `fill` wherever it lands. Separate from the colour so a
    /// palette token can be used at less than full strength without
    /// hand-mixing a second colour.
    public var fillOpacity: Double

    /// `nil` follows the theme's label face.
    public var face: String?
    public var size: CGFloat
    /// `nil` follows the theme's label weight.
    public var weight: Font.Weight?
    public var tracking: CGFloat
    /// `nil` follows the theme's primary text colour.
    public var textColour: Color?

    /// The hairline around the bubble. `nil` draws none — a glass surface
    /// already has a specular edge, and a second line over it reads as a
    /// mistake.
    public var stroke: Color?
    public var strokeWidth: CGFloat

    /// `nil` follows the theme's control radius.
    public var cornerRadius: CGFloat?

    public init(
        shape: GlitchTooltipShape = .roundedRectangle,
        surface: GlitchSurface = .glass(.clear),
        fill: Color? = nil,
        fillOpacity: Double = 1,
        face: String? = nil,
        size: CGFloat = 11,
        weight: Font.Weight? = nil,
        tracking: CGFloat = 1,
        textColour: Color? = nil,
        stroke: Color? = nil,
        strokeWidth: CGFloat = 1,
        cornerRadius: CGFloat? = nil
    ) {
        self.shape = shape
        self.surface = surface
        self.fill = fill
        self.fillOpacity = fillOpacity
        self.face = face
        self.size = size
        self.weight = weight
        self.tracking = tracking
        self.textColour = textColour
        self.stroke = stroke
        self.strokeWidth = strokeWidth
        self.cornerRadius = cornerRadius
    }

    /// The bubble's own font, resolved the same way every other role is: a
    /// named face keeps its family and takes the weight on top, and no face
    /// falls through to the system font in the theme's design.
    public func font(_ theme: GlitchTheme) -> Font {
        let weight = weight ?? theme.typography.labelWeight
        guard let face = face ?? theme.typography.labelFace else {
            return .system(size: size, weight: weight, design: theme.typography.labelDesign)
        }
        return .custom(face, size: size).weight(weight)
    }

    /// The outline itself, ready to fill, stroke and clip glass to.
    ///
    /// Type-erased because the four cases are four different shape types and a
    /// tooltip has to pick between them at runtime. `GlitchAnyInsettableShape` rather
    /// than `AnyShape` because the stroke is drawn with `strokeBorder`, which
    /// keeps the hairline inside the bubble instead of straddling its edge.
    ///
    /// `seed` is only read by the cloud. The caller re-rolls it per appearance,
    /// which is what makes that case randomized rather than merely irregular.
    public func resolvedShape(_ theme: GlitchTheme, seed: UInt64) -> GlitchAnyInsettableShape {
        switch shape {
        case .rectangle:
            GlitchAnyInsettableShape(Rectangle())
        case .roundedRectangle:
            GlitchAnyInsettableShape(
                RoundedRectangle(
                    cornerRadius: cornerRadius ?? theme.metrics.controlRadius,
                    style: .continuous
                )
            )
        case .pill:
            GlitchAnyInsettableShape(Capsule())
        case .thoughtCloud:
            GlitchAnyInsettableShape(GlitchThoughtCloud(seed: seed))
        }
    }

    /// What the surface is handed to draw with, once opacity is folded in.
    ///
    /// Public because the bubble is not the only thing that draws in this
    /// style: an app with a tooltip of its own — one hung off a plain piece of
    /// text, which this system's accessory cannot reach — should be able to
    /// resolve the same fill rather than re-deriving the fallbacks and drifting.
    public func resolvedFill(_ theme: GlitchTheme) -> Color? {
        let base: Color? = switch surface {
        case .solid: fill ?? theme.palette.panel
        case .glass, .blurred: fill
        }
        return base?.opacity(fillOpacity)
    }
}

extension EnvironmentValues {
    @Entry public var glitchTooltipStyle: GlitchTooltipStyle = GlitchTooltipStyle()
}

extension View {
    /// Sets how tooltips in this subtree are drawn.
    public func glitchTooltipStyle(_ style: GlitchTooltipStyle) -> some View {
        environment(\.glitchTooltipStyle, style)
    }
}
