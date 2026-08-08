import SwiftUI

/// Controls doing real work.
///
/// The point of this tab is that every control is wired to something visible.
/// A control that only changes a number in a catalog can hide a lag or a
/// mistracking gesture; one driving a live drawing cannot.
struct PlaygroundView: View {
    @Environment(\.glitchTheme) private var theme

    @State private var parameters = CanvasParameters()
    @State private var preset = "Ribbon"
    @State private var blend = "add"
    @State private var containerWidth: CGFloat = 0

    private let palette: [(color: Color, label: String)] = [
        (GlitchPalette.signatureAccent, "Ember"),
        (Color(glitchHex: 0xFF9F1C), "Amber"),
        (Color(glitchHex: 0x4ECDC4), "Mint"),
        (Color(glitchHex: 0x9B5DE5), "Violet"),
    ]

    private var isWide: Bool { containerWidth > 760 }

    var body: some View {
        Group {
            if isWide {
                HStack(alignment: .top, spacing: 16) {
                    canvas
                    panel.frame(width: 320)
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        canvas.frame(height: 260)
                        panel
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.palette.background)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
    }

    private var canvas: some View {
        GlitchCanvas(parameters: parameters, color: palette[parameters.colorIndex].color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: theme.metrics.panelRadius, style: .continuous)
                    .fill(Color.black.opacity(0.35))
            }
            .overlay {
                RoundedRectangle(cornerRadius: theme.metrics.panelRadius, style: .continuous)
                    .strokeBorder(theme.palette.stroke, lineWidth: 1)
            }
    }

    private var panel: some View {
        ScrollView {
            GlitchPanel {
                actions
                GlitchDivider()

                GlitchSection("Parameters") {
                    GlitchSlider("Flow", value: $parameters.flow, defaultValue: 73)
                    GlitchSlider("Elasticity", value: $parameters.elasticity, defaultValue: 37)
                    GlitchSlider("Noise", value: $parameters.noise, defaultValue: 6)
                    GlitchSlider("Speed", value: $parameters.speed, defaultValue: 5)
                    GlitchSlider("Echoes", value: $parameters.echoes, defaultValue: 68)
                    GlitchSlider("Tension", value: $parameters.tension, defaultValue: 24)
                    GlitchSlider("Clump", value: $parameters.clump, defaultValue: 0)
                    GlitchSlider("Variation", value: $parameters.variation, defaultValue: 10)
                    GlitchSlider("Stroke", value: $parameters.stroke, defaultValue: 6)
                }

                GlitchDivider()

                GlitchSection("Composition") {
                    GlitchStepper("Strands", value: $parameters.strandCount, in: 1...40)
                    GlitchSelect(
                        "Preset",
                        selection: $preset,
                        options: GlitchOption.list(["Ribbon", "Scatter", "Braid", "Pulse"])
                    )
                    GlitchSegmented(
                        "Blend",
                        selection: $blend,
                        options: [
                            GlitchOption("Add", value: "add"),
                            GlitchOption("Screen", value: "screen"),
                            GlitchOption("Overlay", value: "overlay"),
                        ]
                    )
                    GlitchToggle("Playing", isOn: $parameters.isPlaying)
                    GlitchToggle("Mirror", isOn: $parameters.mirrored)
                }

                GlitchDivider()

                GlitchSwatchRow(swatches: palette, selectedIndex: $parameters.colorIndex)

                GlitchButton("Record", systemImage: "record.circle", style: .primary) {}
            }
        }
        .scrollIndicators(.never)
    }

    private var actions: some View {
        VStack(spacing: theme.metrics.spacing) {
            HStack(spacing: theme.metrics.spacing) {
                GlitchButton("Upload Path") {}
                GlitchButton("Export") {}
            }
            HStack(spacing: theme.metrics.spacing) {
                GlitchButton("Copy Settings") {}
                GlitchButton("Save") {}
            }
        }
    }
}

#Preview {
    PlaygroundView()
        .glitchTheme()
        .glitchMotion()
        .preferredColorScheme(.dark)
        .frame(width: 1000, height: 700)
}
