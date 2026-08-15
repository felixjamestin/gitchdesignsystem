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
    @State private var email = ""
    @State private var fieldTrigger = GlitchGooFieldTrigger.focus
    @State private var reach = 1.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                effects
                comparison
                mergePanel
                lightingPanel
                liquidPanel
            }
            .padding(16)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var effects: some View {
        GlitchPanel {
            GlitchSection("Field") {
                GlitchSegmented("Sheds", selection: $fieldTrigger, options:
                    GlitchGooFieldTrigger.allCases.map { GlitchOption($0.title, value: $0) })
                GlitchGooField(
                    text: $email,
                    placeholder: "Enter your email",
                    trigger: fieldTrigger,
                    reach: reach
                )
                .glitchGooStyle(style)
                GlitchSlider("Reach", value: $reach, in: 0.4...2.4, step: 0.05)
                explain("How far the button travels, as a multiple of its own width. Paired with a wide blend it never quite lets go; wind it up and the neck thins until it snaps.")
            }
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
                GlitchSegmented("Renderer", selection: $style.renderer, options:
                    GlitchGooRenderer.allCases.map { GlitchOption($0.title, value: $0) })
                GlitchSlider("Blend", value: blend, in: 0...48)
                GlitchSlider("Crispness", value: $style.crispness, in: 2...60)
                GlitchSlider("Edge softness", value: edgeSoftness, in: 0...4, step: 0.1)
                explain("Blend is the width of the bridge; crispness is how hard the edge lands. Only the distance field keeps them apart — under Blur both fall out of the same Gaussian, which is the compromise that technique makes.")
            }
        }
    }

    private var lightingPanel: some View {
        GlitchPanel {
            GlitchSection("Lighting") {
                GlitchSlider("Rim width", value: rimWidth, in: 0...6, step: 0.1)
                GlitchSlider("Rim opacity", value: $style.rimOpacity, in: 0...1, step: 0.01)
                GlitchSlider("Lit edge", value: $style.rimSecondaryOpacity, in: 0...1, step: 0.01)
                GlitchSlider("Shadow radius", value: shadowRadius, in: 0...24, step: 0.5)
                GlitchSlider("Shadow opacity", value: $style.shadowOpacity, in: 0...1, step: 0.01)
                explain("The rim and the lit edge are distance-field only: they are bands at a known distance from the silhouette, which the field has and the blur has thrown away.")
            }
        }
    }

    private var liquidPanel: some View {
        GlitchPanel {
            GlitchSection("Liquid") {
                GlitchSlider("Wobble", value: wobble, in: 0...6, step: 0.1)
                GlitchSlider("Wobble scale", value: $style.wobbleSpeed, in: 0.2...4, step: 0.1)
                explain("A ripple through the distance field, driven by the control's own progress rather than a clock — so it moves while the shapes do and is still when they arrive. Off at zero, which is where it starts.")
            }
        }
    }

    private func explain(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.metrics.labelSize))
            .foregroundStyle(theme.palette.labelSecondary)
            .fixedSize(horizontal: false, vertical: true)
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

    private var rimWidth: Binding<Double> {
        Binding(get: { Double(style.rimWidth) }, set: { style.rimWidth = CGFloat($0) })
    }

    private var shadowRadius: Binding<Double> {
        Binding(get: { Double(style.shadowRadius) }, set: { style.shadowRadius = CGFloat($0) })
    }

    private var wobble: Binding<Double> {
        Binding(get: { Double(style.wobble) }, set: { style.wobble = CGFloat($0) })
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
