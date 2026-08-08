import SwiftUI

/// The system's colors. One accent; everything else is greyscale.
///
/// Two complete palettes rather than dynamic colors, because the resolution
/// happens once in `.glitchTheme()` and controls then read plain `Color`s —
/// no control needs to know about `colorScheme`.
public struct GlitchPalette: Equatable, Sendable {
    public var background: Color
    public var panel: Color
    public var track: Color
    public var trackHover: Color
    public var trackActive: Color
    public var label: Color
    public var labelSecondary: Color
    public var stroke: Color
    public var accent: Color
    public var danger: Color
    /// Drawn on top of the accent — a knob sitting on a filled track.
    public var onAccent: Color

    /// The hot orange from the first reference. The only chromatic value here.
    public static let signatureAccent = Color(glitchHex: 0xFF5A1F)

    public static let dark = GlitchPalette(
        background: Color(glitchHex: 0x1B1B1D),
        panel: Color(glitchHex: 0x232326),
        track: Color(glitchHex: 0x3A3A3E),
        trackHover: Color(glitchHex: 0x45454A),
        trackActive: Color(glitchHex: 0x4E4E54),
        label: Color(glitchHex: 0xECECEE),
        labelSecondary: Color(glitchHex: 0x95959C),
        stroke: Color.white.opacity(0.08),
        accent: signatureAccent,
        danger: Color(glitchHex: 0xFF4D4D),
        onAccent: Color(glitchHex: 0x1B1B1D)
    )

    public static let light = GlitchPalette(
        background: Color(glitchHex: 0xEFEFF1),
        panel: Color(glitchHex: 0xFBFBFC),
        track: Color(glitchHex: 0xE3E3E7),
        trackHover: Color(glitchHex: 0xD9D9DE),
        trackActive: Color(glitchHex: 0xCECED5),
        label: Color(glitchHex: 0x1B1B1D),
        labelSecondary: Color(glitchHex: 0x6C6C74),
        stroke: Color.black.opacity(0.10),
        accent: signatureAccent,
        danger: Color(glitchHex: 0xE03131),
        onAccent: Color.white
    )

    public static func resolve(_ scheme: ColorScheme) -> GlitchPalette {
        scheme == .dark ? .dark : .light
    }
}

extension Color {
    /// `Color(glitchHex: 0xFF5A1F)` — keeps the palette readable as hex, which
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
