import SwiftUI

/// Every control, in the states worth comparing side by side.
///
/// Hover and focus are deliberately not faked here. Forcing them would mean
/// exposing each control's internal state purely for the catalog, and a
/// screenshot of a hover state proves less than putting the pointer on it —
/// so those two states are live, and the fixed rows are the ones you cannot
/// produce by pointing at them: disabled, errored, and both densities.
struct GalleryView: View {
    @Environment(\.glitchTheme) private var theme
    @Binding var density: GlitchDensity

    @State private var flow = 73.0
    @State private var coarse = 0.4
    @State private var precise = 12.0
    @State private var name = "Felix"
    @State private var invalid = "not-an-email"
    @State private var query = ""
    @State private var loop = true
    @State private var trails = true
    @State private var mode = "Flow"
    @State private var easing = "Spring"
    @State private var align = "center"
    @State private var count = 4.0
    @State private var swatch = 0
    @State private var tags = ["flow", "echo", "noise", "warp"]
    @State private var padX = 30.0
    @State private var padY = 70.0
    @State private var rotation = 35.0

    private let palette: [(color: Color, label: String)] = [
        (GlitchPalette.signatureAccent, "Ember"),
        (Color(glitchHex: 0xFF9F1C), "Amber"),
        (Color(glitchHex: 0x4ECDC4), "Mint"),
        (Color(glitchHex: 0x9B5DE5), "Violet"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                densitySwitch

                group("Slider") {
                    GlitchSlider("Flow", value: $flow)
                    GlitchSlider("Fine", value: $flow, in: 0...1, step: 0.01)
                    // Ten steps or fewer, so every step gets its own tick and a
                    // click lands exactly on one.
                    GlitchSlider("Coarse", value: $coarse, in: 0...1, step: 0.1)
                    GlitchSlider("Disabled", value: $flow).disabled(true)
                }

                group("Numeric") {
                    GlitchDragField("X", value: $precise, in: -500...500)
                    GlitchStepper("Copies", value: $count, in: 1...64)
                    GlitchStepper("Disabled", value: $count).disabled(true)
                }

                group("Text") {
                    GlitchTextField("Name", text: $name, placeholder: "Your name")
                    GlitchTextField(
                        "Email",
                        text: $invalid,
                        placeholder: "you@example.com",
                        error: invalid.contains("@") ? nil : "Needs an @"
                    )
                    GlitchSearchField(text: $query)
                    GlitchTextField("Locked", text: $name).disabled(true)
                }

                group("Booleans") {
                    GlitchToggle("Grain Animated", isOn: $loop)
                    GlitchToggle("Disabled", isOn: $loop).disabled(true)
                    GlitchSwitch("Sliding switch", isOn: $trails)
                    GlitchCheckbox("Show trails", isOn: $trails)
                    GlitchCheckbox("Disabled", isOn: $trails).disabled(true)
                }

                group("Choice") {
                    GlitchRadioGroup(
                        "Mode",
                        selection: $mode,
                        options: GlitchOption.list(["Flow", "Scatter", "Echo"])
                    )
                    GlitchSegmented(
                        "Align",
                        selection: $align,
                        options: [
                            GlitchOption("Left", value: "left", systemImage: "text.alignleft"),
                            GlitchOption("Center", value: "center", systemImage: "text.aligncenter"),
                            GlitchOption("Right", value: "right", systemImage: "text.alignright"),
                        ]
                    )
                    GlitchSelect(
                        "Easing",
                        selection: $easing,
                        options: GlitchOption.list(["Linear", "Ease In", "Ease Out", "Spring"])
                    )
                    GlitchSelect("Empty", selection: $easing, options: [])
                }

                group("Buttons") {
                    GlitchButton("Record", systemImage: "record.circle", style: .primary) {}
                    GlitchButton("Secondary") {}
                    GlitchButton("Ghost", style: .ghost) {}
                    GlitchButton("Disabled", style: .primary) {}.disabled(true)
                }

                group("Color & tags") {
                    GlitchSwatchRow(swatches: palette, selectedIndex: $swatch)
                    GlitchChips("Tags", items: $tags)
                }

                group("Two dimensional") {
                    GlitchXYPad("Displacement", x: $padX, y: $padY)
                    HStack(spacing: 16) {
                        GlitchDial("Rotation", value: $rotation, in: -180...180)
                        GlitchDial("Depth", value: $flow)
                        Spacer()
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(theme.palette.background)
    }

    private var densitySwitch: some View {
        GlitchPanel {
            GlitchSegmented(
                "Density",
                selection: $density,
                options: GlitchDensity.allCases.map { GlitchOption($0.title, value: $0) }
            )
            Text("Compact is the pointer default, comfortable the touch default. Both are always available — this switch is what a Mac app would expose as a display preference.")
                .font(.system(size: theme.metrics.labelSize))
                .foregroundStyle(theme.palette.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func group<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GlitchPanel {
            GlitchSection(title) {
                content()
            }
        }
    }
}

#Preview {
    @Previewable @State var density = GlitchDensity.compact

    GalleryView(density: $density)
        .glitchTheme(density: density)
        .glitchMotion()
        .preferredColorScheme(.dark)
        .frame(width: 640, height: 800)
}
