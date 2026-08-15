import SwiftUI

/// The goo, with every parameter on a slider beside it.
///
/// Both effects read one `GlitchGooStyle`, so tuning moves them together and
/// the question the lab exists to answer — does this setting feel right
/// everywhere, or only where I happened to be looking — stays askable.
struct GooLabView: View {
    @Environment(\.glitchTheme) private var theme

    @State private var style = GlitchGooStyle.standard
    @State private var separation = 44.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                comparison
                mergePanel
            }
            .padding(16)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var comparison: some View {
        GlitchPanel {
            GlitchSection("Renderers") {
                ForEach(GlitchGooRenderer.allCases) { renderer in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(renderer.title)
                            .font(.system(size: theme.metrics.labelSize))
                            .foregroundStyle(theme.palette.labelSecondary)
                        GlitchGooLayer(
                            shapes: pair,
                            style: styled(as: renderer),
                            fill: theme.palette.trackActive,
                            size: CGSize(width: 260, height: 90)
                        )
                    }
                }
                GlitchSlider("Separation", value: $separation, in: 0...160)
            }
        }
    }

    private var mergePanel: some View {
        GlitchPanel {
            GlitchSection("Merge") {
                GlitchSlider("Blend", value: blend, in: 0...48)
                GlitchSlider("Crispness", value: $style.crispness, in: 2...60)
                GlitchSlider("Edge softness", value: edgeSoftness, in: 0...4, step: 0.1)
            }
        }
    }

    private var pair: [GlitchGooShape] {
        [
            .circle(center: CGPoint(x: -separation / 2, y: 0), diameter: 56),
            .circle(center: CGPoint(x: separation / 2, y: 0), diameter: 44),
        ]
    }

    private func styled(as renderer: GlitchGooRenderer) -> GlitchGooStyle {
        var copy = style
        copy.renderer = renderer
        return copy
    }

    // `GlitchSlider` speaks in `Double`; the geometry parameters are `CGFloat`.
    private var blend: Binding<Double> {
        Binding(get: { Double(style.blend) }, set: { style.blend = CGFloat($0) })
    }

    private var edgeSoftness: Binding<Double> {
        Binding(get: { Double(style.edgeSoftness) }, set: { style.edgeSoftness = CGFloat($0) })
    }
}

#Preview {
    GooLabView()
        .frame(width: 640, height: 800)
        .background(GlitchPalette.dark.background)
        .glitchTheme()
        .glitchMotion()
        .preferredColorScheme(.dark)
}
