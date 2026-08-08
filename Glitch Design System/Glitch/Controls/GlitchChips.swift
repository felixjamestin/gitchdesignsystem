import SwiftUI

/// Removable tokens that wrap onto as many lines as they need.
public struct GlitchChips: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.isEnabled) private var isEnabled

    private let label: String?
    @Binding private var items: [String]

    public init(_ label: String? = nil, items: Binding<[String]>) {
        self.label = label
        self._items = items
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label {
                GlitchLabel(label, secondary: true)
            }

            if items.isEmpty {
                GlitchLabel("None", secondary: true)
                    .frame(height: theme.metrics.rowHeight * 0.7, alignment: .leading)
            } else {
                GlitchFlowLayout(spacing: theme.metrics.spacing) {
                    ForEach(items, id: \.self) { item in
                        chip(item)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
        .opacity(isEnabled ? 1 : 0.4)
        .animation(motion.pop, value: items)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label ?? "Tags")
    }

    private func chip(_ item: String) -> some View {
        let metrics = theme.metrics

        return HStack(spacing: 5) {
            Text(item)
                .font(GlitchType.label(theme))
                .tracking(0.3)
                .foregroundStyle(theme.palette.label)

            Button {
                remove(item)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: metrics.iconSize * 0.7, weight: .bold))
                    .foregroundStyle(theme.palette.labelSecondary)
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .accessibilityLabel("Remove \(item)")
        }
        .padding(.horizontal, metrics.hInset * 0.7)
        .frame(height: metrics.rowHeight * 0.72)
        .background {
            Capsule().fill(theme.palette.trackActive)
        }
        .overlay {
            Capsule().strokeBorder(theme.palette.stroke, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func remove(_ item: String) {
        guard isEnabled else { return }
        withAnimation(motion.pop) {
            items.removeAll { $0 == item }
        }
        GlitchHaptics.selection()
    }
}

/// Lays subviews out left to right, wrapping when the next one won't fit.
///
/// SwiftUI has no wrapping stack, and nesting `HStack`s requires knowing the
/// break points in advance — which depends on the width you're being given.
public struct GlitchFlowLayout: Layout {
    public var spacing: CGFloat

    public init(spacing: CGFloat = 6) {
        self.spacing = spacing
    }

    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: widest, height: y + rowHeight)
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview("Chips") {
    @Previewable @State var tags = ["flow", "echo", "noise", "displacement", "warp"]

    VStack(alignment: .leading, spacing: 12) {
        GlitchChips("Tags", items: $tags)
        GlitchChips("Empty", items: .constant([]))
    }
    .padding(24)
    .frame(width: 320)
    .background(GlitchPalette.dark.background)
    .glitchTheme()
    .preferredColorScheme(.dark)
}
