import SwiftUI

/// The system's three text roles.
///
/// Each resolves against the theme rather than against metrics alone, because
/// a style changes not just the size of type but its case, weight, tracking
/// and typeface. `labelText` is the one that matters: it is the single place
/// that decides whether labels are shouted, so no call site has to remember.
public enum GlitchType {

    public static func label(_ theme: GlitchTheme) -> Font {
        resolve(
            face: theme.typography.labelFace,
            size: theme.metrics.labelSize,
            weight: theme.typography.labelWeight,
            design: theme.typography.labelDesign
        )
    }

    /// Numeric readouts. Monospaced in every style, so a changing value never
    /// reflows the row it sits in — no layout jitter, motion rule 3.
    public static func value(_ theme: GlitchTheme) -> Font {
        resolve(
            face: theme.typography.valueFace,
            size: theme.metrics.valueSize,
            weight: theme.typography.valueWeight,
            design: theme.typography.valueDesign
        )
    }

    public static func title(_ theme: GlitchTheme) -> Font {
        resolve(
            face: theme.typography.titleFace,
            size: theme.metrics.titleSize,
            weight: theme.typography.titleWeight,
            design: theme.typography.labelDesign
        )
    }

    /// The system font, or a named family at the same size and weight.
    ///
    /// `Font.custom(_:size:)` scales with Dynamic Type just as `.system(size:)`
    /// does, so naming a face doesn't quietly opt a control out of respecting
    /// the reader's text size — which `.custom(_:fixedSize:)` would have.
    ///
    /// `design` is dropped for a named face because it has nowhere to go: it
    /// selects among the system font's variants, and a custom family has its
    /// own. Weight is applied on top, which works for a variable font or a
    /// family with named weights and is ignored by a single-weight face.
    private static func resolve(
        face: String?,
        size: CGFloat,
        weight: Font.Weight,
        design: Font.Design
    ) -> Font {
        guard let face else {
            return .system(size: size, weight: weight, design: design)
        }
        return .custom(face, size: size).weight(weight)
    }

    /// A label, cased and tracked as the current style writes it.
    public static func labelText(_ text: String, _ theme: GlitchTheme) -> Text {
        Text(theme.display(text))
            .font(label(theme))
            .tracking(theme.typography.tracking)
    }

    /// A numeric readout in the current style.
    public static func valueText(_ text: String, _ theme: GlitchTheme) -> Text {
        Text(text)
            .font(value(theme))
            .tracking(theme.typography.valueTracking)
    }

    /// A section or panel title, cased and tracked as the current style
    /// writes it. Titles fall back to the labels' voice for both unless the
    /// typography separates them.
    public static func titleText(_ text: String, _ theme: GlitchTheme) -> Text {
        Text(theme.displayTitle(text))
            .font(title(theme))
            .tracking(theme.typography.titleTracking ?? theme.typography.tracking)
    }
}

/// A control's label, and whatever follows it.
public struct GlitchLabel: View {
    @Environment(\.glitchTheme) private var theme

    private let text: String
    private let secondary: Bool
    private let accessory: GlitchLabelAccessory

    public init(
        _ text: String,
        secondary: Bool = false,
        accessory: GlitchLabelAccessory = .none
    ) {
        self.text = text
        self.secondary = secondary
        self.accessory = accessory
    }

    public var body: some View {
        HStack(spacing: 4) {
            GlitchType.labelText(text, theme)
                .foregroundStyle(secondary ? theme.palette.labelSecondary : theme.palette.label)
                .lineLimit(1)
            GlitchLabelAccessoryView(accessory: accessory)
        }
    }
}

/// A numeric readout.
///
/// Digits roll rather than swap. Pass `value` where the number is known and
/// the roll picks up its direction from it — counting up and counting down
/// look different, and getting that wrong is more distracting than not
/// animating at all.
///
/// The transition only runs when the change is made inside an animation, which
/// is exactly the distinction the system already draws: values moved under a
/// finger are set in a transaction with animations disabled and so snap, while
/// values that arrive on their own roll into place.
public struct GlitchValueText: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion

    private let text: String
    private let value: Double?
    private let animated: Bool
    private let prominent: Bool

    /// - Parameters:
    ///   - value: the number behind the text, which gives the roll its
    ///     direction. Counting up and counting down look different.
    ///   - animated: whether *this* change should roll. False while a value is
    ///     being dragged or a button held, where rolling would either lag the
    ///     input or stack transitions into a smear.
    public init(
        _ text: String,
        value: Double? = nil,
        animated: Bool = true,
        prominent: Bool = false
    ) {
        self.text = text
        self.value = value
        self.animated = animated
        self.prominent = prominent
    }

    public var body: some View {
        GlitchType.valueText(text, theme)
            .foregroundStyle(prominent ? theme.palette.textPrimary : theme.palette.label)
            .lineLimit(1)
            .contentTransition(value.map { .numericText(value: $0) } ?? .numericText())
            // The animation has to be bound to the value here, not merely
            // inherited from whatever `withAnimation` the caller used.
            // A content transition needs an animation attached to the update
            // that changes the text, and an ambient one from several layers up
            // does not reliably survive the intervening overlays and geometry
            // readers.
            .animation(animated ? motion.glide : nil, value: value)
            .animation(animated ? motion.glide : nil, value: text)
    }
}
