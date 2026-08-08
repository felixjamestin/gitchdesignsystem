import SwiftUI

/// How much room controls give themselves.
///
/// This is the single mechanism that lets one set of control code serve a Mac
/// inspector and a touch screen. Nothing else in the system branches on
/// platform for sizing — controls read `GlitchMetrics` and the metrics read
/// this.
public enum GlitchDensity: String, CaseIterable, Sendable {
    /// Tight rows for pointer input.
    case compact
    /// Rows sized for a thumb.
    case comfortable

    /// Pointer platforms start compact; touch platforms start comfortable.
    /// Overridable per subtree, which is how the Gallery shows both at once.
    public static var platformDefault: GlitchDensity {
        #if os(macOS)
        .compact
        #else
        .comfortable
        #endif
    }

    public var title: String { rawValue.capitalized }
}

/// The few platform facts controls genuinely need, answered in one place so no
/// control body has to ask.
public enum GlitchPlatform {
    /// Whether a pointer is the primary input.
    ///
    /// Used to decide whether a hover-revealed affordance needs a permanent
    /// counterpart. Where there is no hover, the affordance is simply always
    /// visible — the alternative, a long-press, cannot coexist with controls
    /// that begin dragging on touch-down.
    public static var hasPointer: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }
}

/// Every dimension in the system, resolved from a density.
public struct GlitchMetrics: Equatable, Sendable {
    public var rowHeight: CGFloat
    public var controlRadius: CGFloat
    public var panelRadius: CGFloat
    /// Inset for a slider's own label and value, which sit inside the track.
    public var labelInset: CGFloat
    /// Inset for rows whose content is laid out rather than overlaid.
    public var hInset: CGFloat
    public var spacing: CGFloat
    public var panelPadding: CGFloat
    public var iconSize: CGFloat
    public var labelSize: CGFloat
    public var valueSize: CGFloat
    public var titleSize: CGFloat
    public var swatchSize: CGFloat
    public var toggleWidth: CGFloat
    public var markSize: CGFloat

    // MARK: Slider anatomy

    public var handleWidth: CGFloat
    public var handleHeight: CGFloat
    /// How far the handle rides inside the fill's leading edge.
    public var handleInset: CGFloat
    public var hashmarkWidth: CGFloat
    public var hashmarkHeight: CGFloat

    // MARK: Style-supplied

    /// Outline weight for panels and, where a style asks for them, tracks.
    public var borderWidth: CGFloat = 1
    /// Whether control tracks carry a visible outline. The default style's
    /// surfaces separate by tone alone; the other two draw their edges.
    public var tracksAreOutlined: Bool = false
    /// Squares off the handle and hashmarks, which are otherwise capsules.
    public var sharpEdges: Bool = false
    /// Keeps the notch marks permanently visible instead of revealing them on
    /// engagement. Instrument panels print their scales onto the chassis; the
    /// marks are part of the object, not a response to being touched.
    public var hashmarksAlwaysVisible: Bool = false
    /// Extra tracking applied to labels on top of the style's own.
    public var labelTracking: CGFloat = 0

    /// Keeps the handle visible at rest instead of revealing it on engagement.
    public var handleAlwaysVisible: Bool = false

    /// The radius for small parts — handle, hashmarks — which a sharp-edged
    /// style flattens to nothing.
    public func partRadius(_ width: CGFloat) -> CGFloat {
        sharpEdges ? 0 : width / 2
    }

    /// The reference's exact geometry: 36pt rows, 8pt radius, 13pt type.
    public static let compact = GlitchMetrics(
        rowHeight: 36, controlRadius: 8, panelRadius: 14,
        labelInset: 10, hInset: 12, spacing: 6, panelPadding: 12,
        iconSize: 14,
        labelSize: 13, valueSize: 13, titleSize: 13,
        swatchSize: 20, toggleWidth: 96, markSize: 18,
        handleWidth: 3, handleHeight: 20, handleInset: 9,
        hashmarkWidth: 1, hashmarkHeight: 8
    )

    /// The same proportions with touch-sized targets.
    public static let comfortable = GlitchMetrics(
        rowHeight: 48, controlRadius: 11, panelRadius: 18,
        labelInset: 14, hInset: 16, spacing: 8, panelPadding: 16,
        iconSize: 17,
        labelSize: 15, valueSize: 15, titleSize: 15,
        swatchSize: 26, toggleWidth: 120, markSize: 22,
        handleWidth: 4, handleHeight: 26, handleInset: 11,
        hashmarkWidth: 1.5, hashmarkHeight: 10
    )

    public static func resolve(
        _ density: GlitchDensity,
        style: GlitchThemeStyle = .glitch
    ) -> GlitchMetrics {
        var metrics: GlitchMetrics
        switch density {
        case .compact: metrics = .compact
        case .comfortable: metrics = .comfortable
        }
        style.adjust(&metrics)
        return metrics
    }
}
