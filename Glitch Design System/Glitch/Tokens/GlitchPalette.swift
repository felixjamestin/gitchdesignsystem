import SwiftUI

/// The system's colors.
///
/// Every surface is a white (or black) alpha over the panel rather than an
/// opaque grey. That is what lets a control sit on the panel, on the page, or
/// on another control and stay coherent — the same 5% overlay reads correctly
/// against all three, where a fixed grey would only match one.
///
/// There is deliberately no chromatic accent. Selection, fill and activity are
/// all expressed as *more* white, not as a different hue, which is why a dense
/// panel of twenty controls doesn't turn into a fruit salad. An accent can
/// still be supplied per subtree via `.glitchTheme(accent:)`.
public struct GlitchPalette: Equatable, Sendable {
    /// The page behind the panel.
    public var background: Color
    /// The panel itself — the one opaque surface.
    public var panel: Color

    /// Control surface at rest, and its two raised states.
    public var track: Color
    public var trackHover: Color
    public var trackActive: Color

    /// A slider's filled portion. Brightens while the row is engaged.
    public var fill: Color
    public var fillActive: Color

    /// The slider's position marker, and the step ticks behind it.
    public var handle: Color
    public var hashmark: Color

    public var textPrimary: Color
    public var label: Color
    public var labelSecondary: Color

    public var stroke: Color
    public var strokeHover: Color

    /// Used only for focus rings and any opt-in tinting. Neutral by default so
    /// the system stays monochrome unless asked otherwise.
    public var accent: Color
    public var onAccent: Color
    public var danger: Color

    /// The segmented control's pill, and its text.
    ///
    /// Separate from `trackActive` because a style can want selection to read
    /// as a printed switch — solid, inverted — while its ordinary raised
    /// surfaces stay subtle.
    public var selectionFill: Color = .white.opacity(0.11)
    public var onSelection: Color = .white.opacity(0.95)

    /// Label and value colour where a slider's fill has passed underneath.
    ///
    /// A style whose fill is a faint overlay sets this to the same colour as
    /// `label` and nothing appears to happen. A style whose fill is nearly
    /// opaque — film's bar is 86% white on black — has to invert, or the text
    /// vanishes exactly when the value is most worth reading.
    public var onFill: Color = .white.opacity(0.70)

    /// The orange from the original reference, kept available for
    /// `.glitchTheme(accent:)` but no longer the default.
    public static let signatureAccent = Color(glitchHex: 0xFF5A1F)

    public static let dark = GlitchPalette(
        background: Color(glitchHex: 0x161718),
        panel: Color(glitchHex: 0x212121),
        track: .white.opacity(0.05),
        trackHover: .white.opacity(0.10),
        trackActive: .white.opacity(0.11),
        fill: .white.opacity(0.11),
        fillActive: .white.opacity(0.15),
        handle: .white.opacity(0.90),
        hashmark: .white.opacity(0.15),
        textPrimary: .white.opacity(0.95),
        label: .white.opacity(0.70),
        labelSecondary: .white.opacity(0.50),
        stroke: .white.opacity(0.10),
        strokeHover: .white.opacity(0.15),
        accent: .white.opacity(0.90),
        onAccent: Color(glitchHex: 0x161718),
        danger: Color(glitchHex: 0xFF6B6B),
        // An 11% overlay never obscures anything, so nothing inverts.
        onFill: .white.opacity(0.70)
    )

    public static let light = GlitchPalette(
        background: Color(glitchHex: 0xF2F2F4),
        panel: Color(glitchHex: 0xFCFCFD),
        track: .black.opacity(0.05),
        trackHover: .black.opacity(0.09),
        trackActive: .black.opacity(0.11),
        fill: .black.opacity(0.10),
        fillActive: .black.opacity(0.14),
        handle: .black.opacity(0.75),
        hashmark: .black.opacity(0.15),
        textPrimary: .black.opacity(0.92),
        label: .black.opacity(0.68),
        labelSecondary: .black.opacity(0.48),
        stroke: .black.opacity(0.10),
        strokeHover: .black.opacity(0.15),
        accent: .black.opacity(0.75),
        onAccent: .white,
        danger: Color(glitchHex: 0xD93A3A),
        onFill: .black.opacity(0.68)
    )

    public static func resolve(_ scheme: ColorScheme) -> GlitchPalette {
        scheme == .dark ? .dark : .light
    }
}

extension Color {
    /// `Color(glitchHex: 0x161718)` — keeps the palette readable as hex, which
    /// is how these values are designed and compared.
    init(glitchHex hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
