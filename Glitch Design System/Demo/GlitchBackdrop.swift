import SwiftUI

/// Something worth refracting.
///
/// Glass is invisible against a flat colour — the whole material is a
/// statement about what is *behind* it, so judging it against `#0C1018` tells
/// you nothing. This stands in for a photograph: a mesh gradient for the broad
/// colour field, out-of-focus highlights for the specular detail that
/// refraction actually bends, and a little grain so the surface has something
/// fine-grained to distort.
///
/// Generated rather than bundled, so there is no asset to ship and no
/// photographer to credit.
struct GlitchBackdrop: View {
    var body: some View {
        ZStack {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                    [0.0, 0.5], [0.6, 0.4], [1.0, 0.5],
                    [0.0, 1.0], [0.4, 1.0], [1.0, 1.0],
                ],
                colors: [
                    Color(glitchHex: 0x1B2A4A), Color(glitchHex: 0x3E2C63), Color(glitchHex: 0x7A2E52),
                    Color(glitchHex: 0x14406B), Color(glitchHex: 0x6E3A6B), Color(glitchHex: 0xC2523C),
                    Color(glitchHex: 0x0E5C6B), Color(glitchHex: 0x2E7A6B), Color(glitchHex: 0xE0873F),
                ]
            )

            bokeh
            grain
        }
        .ignoresSafeArea()
    }

    /// Out-of-focus highlights. Glass bends the *edges* of things, so a field
    /// of soft discs shows distortion far better than a smooth gradient does.
    private var bokeh: some View {
        Canvas { context, size in
            let discs: [(x: Double, y: Double, r: Double, o: Double)] = [
                (0.14, 0.22, 0.16, 0.30), (0.72, 0.14, 0.10, 0.26),
                (0.88, 0.52, 0.19, 0.22), (0.34, 0.68, 0.13, 0.28),
                (0.58, 0.86, 0.11, 0.20), (0.06, 0.78, 0.09, 0.24),
                (0.46, 0.36, 0.07, 0.34), (0.80, 0.78, 0.14, 0.18),
            ]

            context.addFilter(.blur(radius: 26))
            for disc in discs {
                let diameter = min(size.width, size.height) * disc.r * 2
                let rect = CGRect(
                    x: size.width * disc.x - diameter / 2,
                    y: size.height * disc.y - diameter / 2,
                    width: diameter,
                    height: diameter
                )
                context.fill(Circle().path(in: rect), with: .color(.white.opacity(disc.o)))
            }
        }
        .blendMode(.softLight)
    }

    private var grain: some View {
        Canvas { context, size in
            var generator = SystemRandomNumberGenerator()
            let count = Int(size.width * size.height / 900)
            for _ in 0..<max(0, count) {
                let x = Double.random(in: 0...size.width, using: &generator)
                let y = Double.random(in: 0...size.height, using: &generator)
                let rect = CGRect(x: x, y: y, width: 1.4, height: 1.4)
                context.fill(
                    Circle().path(in: rect),
                    with: .color(.white.opacity(Double.random(in: 0.02...0.07, using: &generator)))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

/// The page behind a screen's content.
///
/// A flat palette colour everywhere except under glass, which needs something
/// to refract or it may as well be a plain fill.
struct GlitchPageBackground: View {
    @Environment(\.glitchTheme) private var theme

    var body: some View {
        switch theme.surface {
        case .solid:
            theme.palette.background
        case .glass:
            GlitchBackdrop()
        }
    }
}

#Preview("Backdrop") {
    GlitchBackdrop()
        .frame(width: 600, height: 400)
}
