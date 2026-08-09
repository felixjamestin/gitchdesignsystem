import SwiftUI

/// A selectable color chip, as in the first reference's palette row.
public struct GlitchSwatch: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.isEnabled) private var isEnabled

    private let color: Color
    private let label: String
    private let isSelected: Bool
    private let action: () -> Void

    @State private var isHovering = false
    @State private var isPressed = false

    public init(
        color: Color,
        label: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.color = color
        self.label = label
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        let metrics = theme.metrics
        let shape = RoundedRectangle(cornerRadius: metrics.controlRadius * 0.8, style: .continuous)

        shape
            .fill(color)
            .frame(height: metrics.swatchSize)
            .overlay { shape.strokeBorder(theme.palette.stroke, lineWidth: 1) }
            .overlay {
                // The ring sits outside the chip so it never covers the color
                // being chosen.
                shape
                    .stroke(theme.palette.accent, lineWidth: 2)
                    .padding(-3)
                    .opacity(isSelected ? 1 : 0)
                    .scaleEffect(isSelected ? 1 : 0.88)
            }
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(isPressed ? 0.94 : (isHovering ? 1.03 : 1))
            .glitchPressable(isPressed: $isPressed, isEnabled: isEnabled) {
                action()
                GlitchHaptics.selection()
                GlitchSound.tick()
            }
            .glitchHover { hovering in
                withAnimation(motion.snap) { isHovering = hovering }
            }
            .animation(motion.pop, value: isSelected)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction(.default, action)
    }
}

/// A row of swatches with a single selection.
public struct GlitchSwatchRow: View {
    @Environment(\.glitchTheme) private var theme

    private let swatches: [(color: Color, label: String)]
    @Binding private var selectedIndex: Int

    public init(swatches: [(color: Color, label: String)], selectedIndex: Binding<Int>) {
        self.swatches = swatches
        self._selectedIndex = selectedIndex
    }

    public var body: some View {
        HStack(spacing: theme.metrics.spacing) {
            ForEach(Array(swatches.enumerated()), id: \.offset) { index, swatch in
                GlitchSwatch(
                    color: swatch.color,
                    label: swatch.label,
                    isSelected: index == selectedIndex
                ) {
                    selectedIndex = index
                }
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Color")
    }
}

#Preview("Swatches") {
    @Previewable @State var selected = 0

    GlitchSwatchRow(
        swatches: [
            (Color(glitchHex: 0xFF5A1F), "Ember"),
            (Color(glitchHex: 0xFF9F1C), "Amber"),
            (Color(glitchHex: 0x4ECDC4), "Mint"),
            (Color(glitchHex: 0x9B5DE5), "Violet"),
        ],
        selectedIndex: $selected
    )
    .padding(24)
    .frame(width: 300)
    .background(GlitchPalette.dark.background)
    .glitchTheme()
    .preferredColorScheme(.dark)
}
