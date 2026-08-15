import SwiftUI

/// Both goo effects on one canvas, with every parameter wired to a control.
///
/// Like the Playground, the point is that the controls drive something live:
/// a slider moving the blend range shows exactly what "goo 24" feels like,
/// which no static preview can.
struct GooLabView: View {
    @Environment(\.glitchTheme) private var theme

    @State private var email = ""
    @State private var submitted: String?

    // Shared liquid
    @State private var goo = 16.0
    @State private var edgeSoftness = 0.0
    @State private var colorIndex = 0

    // Field
    @State private var detachDistance = 16.0
    @State private var buttonDiameter = 34.0

    // Menu
    @State private var gooeyMenu = true
    @State private var petalCount = 5.0
    @State private var endRadius = 110.0
    @State private var springResponse = 0.42
    @State private var springDamping = 0.72
    @State private var staggerMs = 36.0

    @State private var containerWidth: CGFloat = 0

    private let palette: [(color: Color, label: String)] = [
        (GlitchPalette.signatureAccent, "Ember"),
        (Color(glitchHex: 0xFF9F1C), "Amber"),
        (Color(glitchHex: 0x4ECDC4), "Mint"),
        (Color(glitchHex: 0x9B5DE5), "Violet"),
    ]

    private let allItems = [
        PathMenuItem(title: "Flow", systemImage: "wind"),
        PathMenuItem(title: "Echo", systemImage: "waveform.path.ecg"),
        PathMenuItem(title: "Noise", systemImage: "aqi.medium"),
        PathMenuItem(title: "Warp", systemImage: "tornado"),
        PathMenuItem(title: "Trim", systemImage: "scissors"),
        PathMenuItem(title: "Seed", systemImage: "leaf"),
        PathMenuItem(title: "Fold", systemImage: "arrow.triangle.merge"),
        PathMenuItem(title: "Melt", systemImage: "drop"),
    ]

    private var isWide: Bool { containerWidth > 760 }
    private var tint: Color { palette[colorIndex].color }

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
                        canvas.frame(height: 420)
                        panel
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
    }

    private var canvas: some View {
        VStack(spacing: 0) {
            GlitchGooField(
                text: $email,
                placeholder: "Enter your email",
                style: fieldStyle
            ) { value in
                submitted = value
                email = ""
            }
            .frame(width: 300)
            .padding(.top, 48)

            if let submitted {
                Text("Sent to \(submitted)")
                    .font(.system(size: theme.metrics.labelSize))
                    .foregroundStyle(theme.palette.labelSecondary)
                    .padding(.top, 12)
            }

            Spacer()

            // Centred in the remaining space so the full circle of petals has
            // room on every side; its layout footprint is only the trigger.
            GlitchPathMenu(
                items: Array(allItems.prefix(Int(petalCount))),
                variant: gooeyMenu ? .gooey : .standard,
                gooStyle: menuGooStyle,
                configure: { style in
                    style.endRadius = endRadius
                    style.nearRadius = endRadius * 0.92
                    style.farRadius = endRadius * 1.17
                    style.stagger = staggerMs / 1000
                    style.motion = .spring(
                        response: springResponse,
                        dampingRatio: springDamping
                    )
                },
                onSelect: { _ in }
            )

            Spacer()
        }
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

    private var fieldStyle: GlitchGooFieldStyle {
        var style = GlitchGooFieldStyle()
        style.goo = goo
        style.detachDistance = detachDistance
        style.buttonDiameter = buttonDiameter
        style.edgeSoftness = edgeSoftness
        style.spring = Spring(response: springResponse, dampingRatio: springDamping)
        style.tint = tint
        return style
    }

    private var menuGooStyle: GlitchGooMenuStyle {
        var style = GlitchGooMenuStyle()
        style.goo = goo
        style.edgeSoftness = edgeSoftness
        style.tint = tint
        return style
    }

    private var panel: some View {
        ScrollView {
            GlitchPanel {
                GlitchSection("Liquid") {
                    GlitchSlider("Goo", value: $goo, in: 0...40)
                    GlitchSlider("Edge softness", value: $edgeSoftness, in: 0...12, step: 0.5)
                }

                GlitchDivider()

                GlitchSection("Field") {
                    GlitchSlider("Detach", value: $detachDistance, in: 0...60)
                    GlitchSlider("Button size", value: $buttonDiameter, in: 20...48)
                }

                GlitchDivider()

                GlitchSection("Menu") {
                    GlitchToggle("Gooey", isOn: $gooeyMenu)
                    GlitchStepper("Petals", value: $petalCount, in: 1...8)
                    GlitchSlider("Radius", value: $endRadius, in: 60...180)
                    GlitchSlider("Response", value: $springResponse, in: 0.2...1.0, step: 0.01, decimals: 2)
                    GlitchSlider("Damping", value: $springDamping, in: 0.3...1.0, step: 0.01, decimals: 2)
                    GlitchSlider("Stagger", value: $staggerMs, in: 0...120)
                }

                GlitchDivider()

                GlitchSwatchRow(swatches: palette, selectedIndex: $colorIndex)
            }
        }
        .scrollIndicators(.never)
    }
}

#Preview {
    GooLabView()
        .glitchTheme()
        .glitchMotion()
        .preferredColorScheme(.dark)
        .frame(width: 1000, height: 700)
}
