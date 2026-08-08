import SwiftUI

public enum GlitchButtonStyle: Sendable {
    /// The one action a panel is for. Accent-filled.
    case primary
    /// Everything else with a visible edge.
    case secondary
    /// Text-weight actions that shouldn't compete.
    case ghost
}

/// A button in the system's chrome.
public struct GlitchButton: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.isEnabled) private var isEnabled

    private let title: String
    private let systemImage: String?
    private let style: GlitchButtonStyle
    private let action: () -> Void

    @State private var isHovering = false
    @State private var isPressed = false
    @FocusState private var isFocused: Bool

    public init(
        _ title: String,
        systemImage: String? = nil,
        style: GlitchButtonStyle = .secondary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.action = action
    }

    public var body: some View {
        let metrics = theme.metrics
        let shape = RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous)

        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: metrics.iconSize, weight: .semibold))
            }
            Text(title)
                .font(GlitchType.label(metrics))
                .lineLimit(1)
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, metrics.hInset)
        .frame(height: metrics.rowHeight)
        .background(shape.fill(background))
        .overlay { shape.strokeBorder(border, lineWidth: 1) }
        .opacity(isEnabled ? 1 : 0.4)
        .scaleEffect(isPressed && isEnabled ? 0.97 : 1)
        .glitchPressable(isPressed: $isPressed, isEnabled: isEnabled, onTap: fire)
        .glitchHover { hovering in
            withAnimation(motion.snap) { isHovering = hovering }
        }
        .focusable(isEnabled)
        .focused($isFocused)
        .glitchFocusRing(isFocused: isFocused, radius: metrics.controlRadius)
        .onKeyPress(.return) {
            guard isEnabled else { return .ignored }
            fire()
            return .handled
        }
        .animation(motion.snap, value: isHovering)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, fire)
    }

    private func fire() {
        action()
        GlitchHaptics.impact()
    }

    /// All three styles are the same neutral overlay at different strengths.
    /// The reference panel has no coloured button, and introducing one here
    /// would make a single action shout over a panel of twenty.
    private var background: Color {
        let palette = theme.palette
        switch style {
        case .primary:
            if isPressed { return palette.handle.opacity(0.28) }
            return isHovering ? palette.handle.opacity(0.22) : palette.handle.opacity(0.16)
        case .secondary:
            if isPressed { return palette.trackActive }
            return isHovering ? palette.trackHover : palette.track
        case .ghost:
            if isPressed { return palette.trackActive.opacity(0.7) }
            return isHovering ? palette.trackHover.opacity(0.5) : .clear
        }
    }

    private var foreground: Color {
        switch style {
        case .primary: theme.palette.textPrimary
        case .secondary: theme.palette.label
        case .ghost: theme.palette.labelSecondary
        }
    }

    private var border: Color { .clear }
}

#Preview("Buttons") {
    VStack(spacing: 8) {
        GlitchButton("Record", systemImage: "record.circle", style: .primary) {}
        GlitchButton("Upload Path") {}
        GlitchButton("Copy Settings", style: .ghost) {}
        GlitchButton("Disabled") {}.disabled(true)
    }
    .padding(24)
    .frame(width: 280)
    .background(GlitchPalette.dark.background)
    .glitchTheme()
    .preferredColorScheme(.dark)
}
