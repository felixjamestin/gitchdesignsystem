import SwiftUI

/// The system's three text roles.
///
/// One size for everything in a row — label and value are both 13pt medium —
/// so a panel reads as a list rather than a hierarchy. The only distinction
/// between them is the typeface: names are proportional, numbers are not.
public enum GlitchType {

    /// Control labels. Sentence case, never uppercased: these are names, and a
    /// dense panel of shouted names is harder to scan, not easier.
    public static func label(_ metrics: GlitchMetrics) -> Font {
        .system(size: metrics.labelSize, weight: .medium)
    }

    /// Numeric readouts. Monospaced so a changing value doesn't reflow the row
    /// it sits in — no layout jitter, motion rule 3.
    public static func value(_ metrics: GlitchMetrics) -> Font {
        .system(size: metrics.valueSize, weight: .medium, design: .monospaced)
    }

    /// Section and panel headers.
    public static func title(_ metrics: GlitchMetrics) -> Font {
        .system(size: metrics.titleSize, weight: .semibold)
    }
}

/// A control's label.
public struct GlitchLabel: View {
    @Environment(\.glitchTheme) private var theme

    private let text: String
    private let secondary: Bool

    public init(_ text: String, secondary: Bool = false) {
        self.text = text
        self.secondary = secondary
    }

    public var body: some View {
        Text(text)
            .font(GlitchType.label(theme.metrics))
            .lineLimit(1)
            .foregroundStyle(secondary ? theme.palette.labelSecondary : theme.palette.label)
    }
}

/// A numeric readout.
public struct GlitchValueText: View {
    @Environment(\.glitchTheme) private var theme

    private let text: String
    private let prominent: Bool

    public init(_ text: String, prominent: Bool = false) {
        self.text = text
        self.prominent = prominent
    }

    public var body: some View {
        Text(text)
            .font(GlitchType.value(theme.metrics))
            .foregroundStyle(prominent ? theme.palette.textPrimary : theme.palette.label)
            .lineLimit(1)
    }
}
