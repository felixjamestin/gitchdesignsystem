import SwiftUI

/// Which family a text style draws from; `system` and `rounded` always use the system font.
public enum GlitchFontFamily: Sendable {
    case sans, mono, display, system, rounded
}

/// The typefaces behind the scale's named families; nil means the system font.
public struct GlitchFontFamilies: Equatable, Sendable {
    public var sans: String?
    public var mono: String?
    public var display: String?

    public init(sans: String? = nil, mono: String? = nil, display: String? = nil) {
        self.sans = sans
        self.mono = mono
        self.display = display
    }

    public static let system = GlitchFontFamilies()

    /// The faces every text style resolves against; an app sets this once at launch, before any view draws.
    nonisolated(unsafe) public static var installed = GlitchFontFamilies.system

    /// The named face for a family, or nil when it draws in the system font.
    public func face(for family: GlitchFontFamily) -> String? {
        switch family {
        case .sans: sans
        case .mono: mono
        case .display: display ?? sans
        case .system, .rounded: nil
        }
    }
}

/// One step of the type scale, sized after the macOS text styles, with tracking in ems that only uppercase styles use.
public struct GlitchTextStyle: Equatable, Sendable {
    public var size: CGFloat
    public var weight: Font.Weight
    public var family: GlitchFontFamily
    public var tracking: CGFloat
    public var isUppercase: Bool

    public init(size: CGFloat, weight: Font.Weight = .regular, family: GlitchFontFamily = .sans,
                tracking: CGFloat = 0, isUppercase: Bool = false) {
        self.size = size
        self.weight = weight
        self.family = family
        self.tracking = tracking
        self.isUppercase = isUppercase
    }

    /// Glyphs inside keycaps. Below Apple's 10-point minimum, so never words.
    public static let micro = GlitchTextStyle(size: 8, weight: .semibold, family: .rounded)
    /// Tiny uppercase labels. Below Apple's minimum, so short caps only.
    public static let caps = GlitchTextStyle(size: 9, weight: .semibold, tracking: 0.16, isUppercase: true)
    /// Helper text under a control, badges. The macOS caption size.
    public static let caption = GlitchTextStyle(size: 10)
    /// Secondary details and tooltips. The macOS subheadline size.
    public static let footnote = GlitchTextStyle(size: 11)
    /// Labels, key hints and small readouts. The macOS callout size.
    public static let callout = GlitchTextStyle(size: 12)
    /// Menus, settings rows and running text. The macOS body size.
    public static let body = GlitchTextStyle(size: 13)
    /// List titles and inputs.
    public static let bodyLarge = GlitchTextStyle(size: 14, weight: .medium)
    /// Heading 4. The macOS title 3 size.
    public static let h4 = GlitchTextStyle(size: 15, weight: .semibold)
    /// Heading 3. Close to the body size, so weight carries the step.
    public static let h3 = GlitchTextStyle(size: 18, weight: .semibold)
    /// Heading 2, section heads. The macOS title 1 size.
    public static let h2 = GlitchTextStyle(size: 22, weight: .semibold)
    /// Heading 1, a window's title.
    public static let h1 = GlitchTextStyle(size: 28, weight: .semibold)
    /// Empty states and large dates.
    public static let display = GlitchTextStyle(size: 36, weight: .medium, family: .display)
    /// A single hero number, such as a large clock.
    public static let hero = GlitchTextStyle(size: 76, weight: .thin, family: .display)

    /// A glass button's label: mono capitals with a little air.
    public static let button = GlitchTextStyle(size: 12, weight: .medium, family: .mono, tracking: 0.08, isUppercase: true)
    /// A control's label in mono capitals, as in a tuning panel.
    public static let controlCaps = GlitchTextStyle(size: 10, family: .mono, tracking: 0.18, isUppercase: true)

    public static let scale: [GlitchTextStyle] = [micro, caps, caption, footnote, callout, body, bodyLarge, h4, h3, h2, h1, display, hero]

    public func family(_ family: GlitchFontFamily) -> Self {
        var copy = self
        copy.family = family
        return copy
    }

    public func weight(_ weight: Font.Weight) -> Self {
        var copy = self
        copy.weight = weight
        return copy
    }

    /// Tracking in points at this size.
    public var trackingPoints: CGFloat { tracking * size }

    /// The face this style draws in with the installed families, or nil for the system font.
    public func face(in families: GlitchFontFamilies = .installed) -> String? {
        families.face(for: family)
    }

    /// The font for contexts that take a `Font`; `glitchFont(_:)` also applies tracking and case.
    public func font(in families: GlitchFontFamilies = .installed) -> Font {
        if let face = face(in: families) {
            return .custom(face, size: size).weight(weight)
        }
        let design: Font.Design = switch family {
        case .mono: .monospaced
        case .rounded: .rounded
        default: .default
        }
        return .system(size: size, weight: weight, design: design)
    }
}

extension View {
    /// Sets a text style from the scale, with its tracking and case.
    public func glitchFont(_ style: GlitchTextStyle) -> some View {
        modifier(GlitchFontModifier(style: style))
    }
}

private struct GlitchFontModifier: ViewModifier {
    let style: GlitchTextStyle

    // Case and tracking are left unset unless the style asks, so a caller's own outside this modifier still apply.
    @ViewBuilder func body(content: Content) -> some View {
        let font = content.font(style.font())
        switch (style.isUppercase, style.tracking != 0) {
        case (true, true): font.textCase(.uppercase).tracking(style.trackingPoints)
        case (true, false): font.textCase(.uppercase)
        case (false, true): font.tracking(style.trackingPoints)
        case (false, false): font
        }
    }
}
