import SwiftUI

/// Geometry and behaviour for ``GlitchGooField``.
///
/// Motion still comes from ``GlitchMotion``. This style only changes the
/// field's anatomy and the timing offset of its icon reveal.
public struct GlitchGooFieldStyle: Equatable, Sendable {
    /// Width of the text capsule before the action button leaves it.
    public var width: CGFloat = 260
    /// Capsule height as a multiple of the theme row height.
    public var heightScale: CGFloat = 1.15
    /// Action button diameter as a multiple of the capsule height.
    public var buttonScale: CGFloat = 1
    /// Space kept in the layout, in button diameters. Reach changes inside this
    /// space without moving neighbouring controls.
    public var reservedReach: CGFloat = 1.75
    /// Blur on the action symbol before it becomes visible.
    public var iconBlur: CGFloat = 5
    /// Delay before the action symbol appears. The surface itself moves at once.
    public var iconRevealDelay: Double = 0.06
    /// Small pointer lift for the whole control.
    public var hoverScale: CGFloat = 1.008
    /// Remove text focus after the action runs.
    public var dismissesOnSubmit: Bool = true

    public init() {}

    public static let standard = GlitchGooFieldStyle()

    public static var compact: GlitchGooFieldStyle {
        var style = GlitchGooFieldStyle()
        style.width = 220
        style.heightScale = 1
        style.reservedReach = 1.65
        style.iconBlur = 3
        return style
    }
}

/// Stable field geometry used by the view and by its tests.
public struct GlitchGooFieldGeometry: Equatable, Sendable {
    public let fieldWidth: CGFloat
    public let fieldHeight: CGFloat
    public let buttonDiameter: CGFloat
    public let reach: CGFloat
    public let reservedReach: CGFloat

    public init(
        fieldWidth: CGFloat,
        fieldHeight: CGFloat,
        buttonDiameter: CGFloat,
        reach: CGFloat,
        reservedReach: CGFloat
    ) {
        self.fieldWidth = max(fieldWidth, 1)
        self.fieldHeight = max(fieldHeight, 1)
        self.buttonDiameter = max(buttonDiameter, 1)
        self.reach = max(reach, 0)
        self.reservedReach = max(reservedReach, max(reach, 0))
    }

    public var stageWidth: CGFloat { fieldWidth + buttonDiameter * reservedReach }
    public var capsuleCenterX: CGFloat { -(buttonDiameter * reservedReach) / 2 }
    public var mergedButtonCenterX: CGFloat {
        capsuleCenterX + fieldWidth / 2 - buttonDiameter / 2
    }
    public var expandedButtonCenterX: CGFloat {
        mergedButtonCenterX + buttonDiameter * reach
    }

    public func buttonCenterX(progress: Double) -> CGFloat {
        let amount = min(max(progress, 0), 1)
        return mergedButtonCenterX
            + (expandedButtonCenterX - mergedButtonCenterX) * amount
    }
}

extension EnvironmentValues {
    @Entry public var glitchGooFieldStyle: GlitchGooFieldStyle = .standard
}

extension View {
    public func glitchGooFieldStyle(_ style: GlitchGooFieldStyle) -> some View {
        environment(\.glitchGooFieldStyle, style)
    }
}
