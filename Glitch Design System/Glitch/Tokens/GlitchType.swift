import SwiftUI

/// The system's three text roles.
public enum GlitchType {

    /// Uppercase micro-type for control labels, per the first reference.
    public static func label(_ metrics: GlitchMetrics) -> Font {
        .system(size: metrics.labelSize, weight: .semibold)
    }

    /// Numeric readouts. Monospaced digits so a changing value doesn't
    /// reflow the row it sits in — rule 3, no layout jitter.
    public static func value(_ metrics: GlitchMetrics) -> Font {
        .system(size: metrics.valueSize, weight: .medium).monospacedDigit()
    }

    /// Section and panel headers.
    public static func title(_ metrics: GlitchMetrics) -> Font {
        .system(size: metrics.titleSize, weight: .semibold)
    }
}

/// A control's label: uppercased, tracked out, and never wrapping.
public struct GlitchLabel: View {
    @Environment(\.glitchTheme) private var theme

    private let text: String
    private let secondary: Bool

    public init(_ text: String, secondary: Bool = false) {
        self.text = text
        self.secondary = secondary
    }

    public var body: some View {
        Text(text.uppercased())
            .font(GlitchType.label(theme.metrics))
            .tracking(0.7)
            .lineLimit(1)
            .foregroundStyle(secondary ? theme.palette.labelSecondary : theme.palette.label)
    }
}

/// A numeric readout, right-aligned in a fixed-width column so the digits
/// don't shift the row as they change.
public struct GlitchValueText: View {
    @Environment(\.glitchTheme) private var theme

    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(GlitchType.value(theme.metrics))
            .foregroundStyle(theme.palette.labelSecondary)
            .lineLimit(1)
            .frame(minWidth: theme.metrics.valueSize * 3, alignment: .trailing)
    }
}
