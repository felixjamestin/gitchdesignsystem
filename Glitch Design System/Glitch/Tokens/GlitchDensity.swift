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
    public var hInset: CGFloat
    public var spacing: CGFloat
    public var panelPadding: CGFloat
    public var knobWidth: CGFloat
    public var iconSize: CGFloat
    public var labelSize: CGFloat
    public var valueSize: CGFloat
    public var titleSize: CGFloat
    public var swatchSize: CGFloat
    public var toggleWidth: CGFloat
    public var markSize: CGFloat

    public static let compact = GlitchMetrics(
        rowHeight: 28, controlRadius: 9, panelRadius: 16,
        hInset: 10, spacing: 6, panelPadding: 12,
        knobWidth: 2, iconSize: 12,
        labelSize: 10, valueSize: 11, titleSize: 12,
        swatchSize: 26, toggleWidth: 40, markSize: 16
    )

    public static let comfortable = GlitchMetrics(
        rowHeight: 44, controlRadius: 12, panelRadius: 20,
        hInset: 14, spacing: 10, panelPadding: 16,
        knobWidth: 2.5, iconSize: 15,
        labelSize: 12, valueSize: 13, titleSize: 14,
        swatchSize: 40, toggleWidth: 56, markSize: 22
    )

    public static func resolve(_ density: GlitchDensity) -> GlitchMetrics {
        switch density {
        case .compact: .compact
        case .comfortable: .comfortable
        }
    }
}
