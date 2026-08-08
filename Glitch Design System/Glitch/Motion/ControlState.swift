import SwiftUI

/// What a control is currently going through.
///
/// Independent flags rather than an enum, because these genuinely co-occur: a
/// control can be focused *and* hovered *and* disabled at once. An enum would
/// force a precedence decision at every assignment site, where the information
/// to make it is missing. Here precedence is decided once, below, at the point
/// of rendering.
public struct ControlState: Equatable, Sendable {
    public var isHovering = false
    public var isPressed = false
    public var isFocused = false
    public var isDragging = false
    public var isDisabled = false
    public var isErrored = false

    public init(
        isHovering: Bool = false,
        isPressed: Bool = false,
        isFocused: Bool = false,
        isDragging: Bool = false,
        isDisabled: Bool = false,
        isErrored: Bool = false
    ) {
        self.isHovering = isHovering
        self.isPressed = isPressed
        self.isFocused = isFocused
        self.isDragging = isDragging
        self.isDisabled = isDisabled
        self.isErrored = isErrored
    }

    /// Precedence: disabled → active → hovering or focused → resting.
    ///
    /// Focus deliberately resolves to the same lift as hover. With no focus
    /// ring anywhere in the system, the surface is the only thing left to say
    /// "the keyboard is pointed here", and a tabbing user gets exactly the
    /// feedback a pointer user already had.
    public func trackFill(_ palette: GlitchPalette) -> Color {
        if isDisabled { return palette.track.opacity(0.4) }
        if isDragging || isPressed { return palette.trackActive }
        if isHovering || isFocused { return palette.trackHover }
        return palette.track
    }

    /// Precedence: disabled → errored → resting. Focus is carried by the fill,
    /// not by the border.
    public func strokeColor(_ palette: GlitchPalette) -> Color {
        if isDisabled { return palette.stroke.opacity(0.5) }
        if isErrored { return palette.danger }
        return palette.stroke
    }

    public var strokeWidth: CGFloat {
        isErrored && !isDisabled ? 1.5 : 1
    }

    /// Deliberately subtle. A press should register, not perform.
    public var pressScale: CGFloat {
        isPressed && !isDisabled ? 0.985 : 1
    }

    public var contentOpacity: Double {
        isDisabled ? 0.4 : 1
    }

    /// Hover-revealed affordances fade in on pointer platforms; on touch,
    /// `isHovering` is never true, so they stay hidden and the control offers
    /// a long-press instead.
    public var revealsAffordances: Bool {
        isHovering && !isDisabled
    }
}
