import SwiftUI

// MARK: - Hover

/// Reports pointer hover.
///
/// `.onHover` already does the right thing everywhere — real hover on macOS,
/// pointer hover on iPad, silence on iPhone. Routing through one modifier keeps
/// the intent legible at call sites and leaves one place to change if that ever
/// stops being true.
///
/// Anything revealed by hover must also be reachable without it.
extension View {
    public func glitchHover(_ onChange: @escaping (Bool) -> Void) -> some View {
        onHover(perform: onChange)
    }
}

// MARK: - Modifier keys

extension View {
    /// Reports the modifier keys currently held.
    ///
    /// `onModifierKeysChanged` is macOS-only, so this is a no-op elsewhere and
    /// modifiers stay empty. Controls must therefore treat modifier-key
    /// behaviour as an accelerator, never as the only route to something:
    /// shift-drag refines a value on a Mac, and a drag away from the control
    /// does the same under a finger.
    public func glitchModifierKeys(_ onChange: @escaping (EventModifiers) -> Void) -> some View {
        #if os(macOS)
        return onModifierKeysChanged(mask: [.shift, .option]) { _, active in
            onChange(active)
        }
        #else
        return self
        #endif
    }
}

// MARK: - Press

private struct GlitchPressable: ViewModifier {
    @Environment(\.glitchMotion) private var motion

    @Binding var isPressed: Bool
    var isEnabled: Bool
    var onTap: () -> Void

    @State private var size: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard isEnabled, !isPressed else { return }
                        // Acknowledge on touch-down, before we know whether
                        // this becomes a tap. Waiting for the release is what
                        // makes a control feel unresponsive.
                        withAnimation(motion.snap) { isPressed = true }
                    }
                    .onEnded { value in
                        guard isEnabled else { return }
                        withAnimation(motion.snap) { isPressed = false }

                        // Only commit if the finger came up inside: dragging
                        // off a control is how you change your mind.
                        let bounds = CGRect(origin: .zero, size: size)
                        if bounds.contains(value.location) {
                            onTap()
                        }
                    }
            )
            .onChange(of: isEnabled) { _, enabled in
                if !enabled { isPressed = false }
            }
    }
}

extension View {
    /// Press feedback with cancel-on-slide-off, reporting press state so the
    /// caller can render it.
    public func glitchPressable(
        isPressed: Binding<Bool>,
        isEnabled: Bool = true,
        onTap: @escaping () -> Void
    ) -> some View {
        modifier(GlitchPressable(isPressed: isPressed, isEnabled: isEnabled, onTap: onTap))
    }
}

// MARK: - Focus ring

private struct GlitchFocusRing: ViewModifier {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion

    var isFocused: Bool
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            // The platform's own focus ring is suppressed here rather than at
            // each call site: every control that draws this ring would
            // otherwise get a blue halo around it as well, in a system that
            // has no blue in it.
            .focusEffectDisabled()
            .overlay {
                RoundedRectangle(cornerRadius: radius + 2, style: .continuous)
                    .stroke(theme.palette.accent.opacity(isFocused ? 0.45 : 0), lineWidth: 2)
                    .padding(-2.5)
            }
            .animation(motion.snap, value: isFocused)
    }
}

extension View {
    /// The system's keyboard-focus indicator: an accent halo just outside the
    /// control's own edge, so it reads as focus rather than as a border change.
    public func glitchFocusRing(isFocused: Bool, radius: CGFloat) -> some View {
        modifier(GlitchFocusRing(isFocused: isFocused, radius: radius))
    }
}
