import CoreGraphics

/// Spacing on an 8-point grid, named as the Glitch web tokens are, where `s100` is 1 × 8 and the 4 and 12 steps stay inside components.
public enum GlitchSpace {
    public static let s0: CGFloat = 0
    /// Inside components only.
    public static let s050: CGFloat = 4
    public static let s100: CGFloat = 8
    /// Inside components only.
    public static let s150: CGFloat = 12
    public static let s200: CGFloat = 16
    public static let s300: CGFloat = 24
    public static let s400: CGFloat = 32
    public static let s500: CGFloat = 40
    public static let s600: CGFloat = 48
    public static let s800: CGFloat = 64
    public static let s1000: CGFloat = 80

    /// A point or two of optical alignment, never spacing.
    public static let nudge1: CGFloat = 1
    public static let nudge2: CGFloat = 2

    /// The steps for layout between things, which are all multiples of 8.
    public static let layoutSteps: [CGFloat] = [s0, s100, s200, s300, s400, s500, s600, s800, s1000]
}

/// Padding inside a container, named by the container's role.
public enum GlitchInset {
    /// Tags and keycaps.
    public static let chip = GlitchSpace.s050
    /// Buttons, rows and menu items, left and right.
    public static let control = GlitchSpace.s150
    /// Side panels and popovers.
    public static let panel = GlitchSpace.s200
    /// Cards.
    public static let card = GlitchSpace.s300
    /// Dialogs and sheets.
    public static let dialog = GlitchSpace.s400
}

/// Space between siblings, named by what they are.
public enum GlitchGap {
    /// An icon and its label.
    public static let inline = GlitchSpace.s050
    /// Rows in a list.
    public static let stack = GlitchSpace.s100
    /// Groups of rows, and buttons side by side.
    public static let group = GlitchSpace.s200
    /// Sections of a panel or page.
    public static let section = GlitchSpace.s300
}
