import SwiftUI

/// The system's three text roles.
///
/// Each resolves against the theme rather than against metrics alone, because
/// a style changes not just the size of type but its case, weight, tracking
/// and typeface. `labelText` is the one that matters: it is the single place
/// that decides whether labels are shouted, so no call site has to remember.
public enum GlitchType {

    public static func label(_ theme: GlitchTheme) -> Font {
        .system(
            size: theme.metrics.labelSize,
            weight: theme.typography.labelWeight,
            design: theme.typography.labelDesign
        )
    }

    /// Numeric readouts. Monospaced in every style, so a changing value never
    /// reflows the row it sits in — no layout jitter, motion rule 3.
    public static func value(_ theme: GlitchTheme) -> Font {
        .system(
            size: theme.metrics.valueSize,
            weight: theme.typography.valueWeight,
            design: theme.typography.valueDesign
        )
    }

    public static func title(_ theme: GlitchTheme) -> Font {
        .system(
            size: theme.metrics.titleSize,
            weight: theme.typography.titleWeight,
            design: theme.typography.labelDesign
        )
    }

    /// A label, cased and tracked as the current style writes it.
    public static func labelText(_ text: String, _ theme: GlitchTheme) -> Text {
        Text(theme.display(text))
            .font(label(theme))
            .tracking(theme.typography.tracking)
    }

    /// A numeric readout in the current style.
    public static func valueText(_ text: String, _ theme: GlitchTheme) -> Text {
        Text(text).font(value(theme))
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
        GlitchType.labelText(text, theme)
            .foregroundStyle(secondary ? theme.palette.labelSecondary : theme.palette.label)
            .lineLimit(1)
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
        GlitchType.valueText(text, theme)
            .foregroundStyle(prominent ? theme.palette.textPrimary : theme.palette.label)
            .lineLimit(1)
    }
}
