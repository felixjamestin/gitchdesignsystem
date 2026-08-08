import SwiftUI

public struct GlitchTabItem: Identifiable, Hashable, Sendable {
    public let id: Int
    public let title: String
    public let systemImage: String

    public init(id: Int, title: String, systemImage: String) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
    }
}

/// A tab bar that moves like it enjoys it.
///
/// Built rather than borrowed because `TabView` owns its own transition and
/// won't discuss it — there is no way to make the system control overshoot, or
/// to move the incoming screen in the direction you actually travelled.
///
/// Three things carry the feel:
///
/// - The indicator is a single view moved with `matchedGeometryEffect` on the
///   `travel` token, so it overshoots its destination and settles back.
/// - The selected symbol plays SF Symbols' own bounce, which fires on arrival
///   rather than on departure — the tab reacts to being landed on.
/// - Unselected tabs sit fractionally smaller, so selecting one is a small
///   physical rise rather than only a colour change.
public struct GlitchTabBar: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion

    @Binding private var selection: Int
    private let items: [GlitchTabItem]

    @Namespace private var indicator
    @State private var hovered: Int?

    public init(selection: Binding<Int>, items: [GlitchTabItem]) {
        self._selection = selection
        self.items = items
    }

    public var body: some View {
        let metrics = theme.metrics
        let shape = RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous)

        HStack(spacing: 0) {
            ForEach(items) { item in
                tab(item)
            }
        }
        .padding(3)
        .glitchSurface(shape, fill: theme.palette.track)
        .overlay {
            shape.strokeBorder(
                metrics.tracksAreOutlined ? theme.palette.stroke : .clear,
                lineWidth: metrics.borderWidth
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tabs")
    }

    private func tab(_ item: GlitchTabItem) -> some View {
        let metrics = theme.metrics
        let isSelected = item.id == selection
        let innerRadius = max(2, metrics.controlRadius - 3)

        return ZStack {
            if isSelected {
                RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                    .fill(theme.palette.selectionFill)
                    .matchedGeometryEffect(id: "tabIndicator", in: indicator)
            } else if hovered == item.id {
                RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                    .fill(theme.palette.trackHover)
            }

            HStack(spacing: 6) {
                Image(systemName: item.systemImage)
                    .font(.system(size: metrics.iconSize, weight: .semibold))
                    .symbolEffect(.bounce, options: .nonRepeating, value: isSelected)
                GlitchType.labelText(item.title, theme)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? theme.palette.onSelection : theme.palette.label)
            // The unselected tabs sit back a little, so arriving on one is a
            // rise as well as a recolour.
            .scaleEffect(isSelected ? 1 : 0.94)
            .animation(motion.travel, value: isSelected)
        }
        .frame(maxWidth: .infinity)
        .frame(height: metrics.rowHeight)
        .contentShape(Rectangle())
        .onTapGesture { select(item.id) }
        .glitchHover { hovering in
            withAnimation(motion.tint) { hovered = hovering ? item.id : nil }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { select(item.id) }
    }

    private func select(_ id: Int) {
        guard id != selection else { return }
        withAnimation(motion.travel) { selection = id }
        GlitchHaptics.impact()
        GlitchSound.commit()
    }
}

#Preview("Tab bar") {
    @Previewable @State var selection = 0

    GlitchTabBar(
        selection: $selection,
        items: [
            GlitchTabItem(id: 0, title: "Playground", systemImage: "slider.horizontal.3"),
            GlitchTabItem(id: 1, title: "Gallery", systemImage: "square.grid.2x2"),
            GlitchTabItem(id: 2, title: "Motion", systemImage: "waveform.path"),
        ]
    )
    .padding(16)
    .frame(width: 420)
    .background(GlitchPalette.dark.background)
    .glitchTheme()
    .preferredColorScheme(.dark)
}
