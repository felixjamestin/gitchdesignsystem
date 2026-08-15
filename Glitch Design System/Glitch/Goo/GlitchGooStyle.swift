import SwiftUI

// MARK: - Renderer

/// How the merge is actually drawn.
///
/// Two techniques for one effect, because they fail in different places. The
/// distance field is exact and cheap but can only merge shapes it has been
/// given the maths for; the blur is the reference's own method, works on
/// anything, and pays an offscreen composite and a full Gaussian every frame to
/// do it.
public enum GlitchGooRenderer: String, CaseIterable, Hashable, Sendable, Identifiable {

    /// Analytic signed distance field in a Metal fragment shader. One pass, no
    /// texture sampling, no offscreen buffer. The default.
    case sdf

    /// Blur the shapes and threshold the result — a port of the SVG filter the
    /// effect is borrowed from. Kept as a reference renderer and because it is
    /// the only path that could ever merge arbitrary views.
    case blurThreshold

    /// No merging: the shapes are drawn as they are. What the delight switch
    /// resolves to, and the floor everything else degrades towards.
    case plain

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .sdf: "Distance field"
        case .blurThreshold: "Blur"
        case .plain: "Plain"
        }
    }
}

// MARK: - Style

/// Every knob the goo exposes.
///
/// A plain value type, so configurations are cheap to build, compare and store —
/// the same shape `PathMenuStyle` takes, for the same reasons.
public struct GlitchGooStyle: Equatable, Sendable {

    // Merge ------------------------------------------------------------------

    public var renderer: GlitchGooRenderer = .sdf

    /// The widest gap, in points, that two shapes still bridge across — and so
    /// also how thick the bridge between them is.
    ///
    /// Independent of `crispness`. Under `.blurThreshold` it becomes a blur
    /// radius, which does not separate the two — so the slider means roughly the
    /// same thing in both renderers, but only one of them honours the promise.
    public var blend: CGFloat = 18

    /// How hard the merged edge lands. Under `.blurThreshold` this is the alpha
    /// multiplier the reference calls contrast.
    public var crispness: Double = 18

    /// Antialias width in points. `.sdf` only: the blur path's edge softness is
    /// a consequence of `crispness` and cannot be set apart from it.
    public var edgeSoftness: CGFloat = 1

    // Lighting ---------------------------------------------------------------

    /// Inner highlight, drawn as a band just inside the merged silhouette.
    /// The reference reaches this by eroding the shape and subtracting.
    public var rimWidth: CGFloat = 1
    public var rimOpacity: Double = 0.28
    /// The offset twin of that highlight, which is what stops the rim reading as
    /// a uniform outline and starts it reading as a lit edge.
    public var rimOffsetY: CGFloat = 1
    public var rimSecondaryOpacity: Double = 0.2

    /// Outer shadow, the band just outside the silhouette — the reference's
    /// dilate pass.
    public var shadowRadius: CGFloat = 6
    public var shadowOpacity: Double = 0.22
    public var shadowOffsetY: CGFloat = 2

    // Surface ----------------------------------------------------------------

    /// `nil` takes the theme's `trackActive`, so goo matches every other resting
    /// surface in the system without being told to.
    public var fill: Color?

    // Liquid -----------------------------------------------------------------

    /// Amplitude, in points, of a sinusoidal displacement of the distance field.
    ///
    /// Zero by default. It costs a `sin` per shape per pixel, and it is the
    /// parameter most likely to grate on the hundredth use — which is the same
    /// reasoning that keeps the rest of the game-feel layer behind a switch.
    public var wobble: CGFloat = 0
    public var wobbleSpeed: Double = 1

    public init() {}
}

// MARK: - Presets

extension GlitchGooStyle {

    /// The reference's own feel: a generous bridge that necks slowly.
    public static let standard = GlitchGooStyle()

    /// Barely merged — shapes bond only when nearly touching. For dense
    /// arrangements where a wide bridge would read as a smear.
    public static var tight: GlitchGooStyle {
        var style = GlitchGooStyle()
        style.blend = 7
        style.crispness = 26
        style.shadowRadius = 4
        return style
    }

    /// Heavily liquid: shapes reach for one another from far apart and part
    /// reluctantly.
    public static var loose: GlitchGooStyle {
        var style = GlitchGooStyle()
        style.blend = 34
        style.crispness = 12
        style.edgeSoftness = 1.5
        style.shadowRadius = 9
        style.wobble = 1.5
        return style
    }
}

// MARK: - Environment

extension EnvironmentValues {
    /// Style used by any goo that was not given one explicitly.
    @Entry public var glitchGooStyle: GlitchGooStyle = .standard
}

extension View {
    /// Sets the goo style for every effect in this subtree.
    public func glitchGooStyle(_ style: GlitchGooStyle) -> some View {
        environment(\.glitchGooStyle, style)
    }
}
