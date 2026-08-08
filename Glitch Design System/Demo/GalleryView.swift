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

    @Binding var style: GlitchThemeStyle
    @Binding var glass: GlitchGlassVariant
    @Binding var scheme: ColorScheme
    @Binding var density: GlitchDensity
    @Binding var delight: Bool

    @State private var notches: GlitchNotchSnapping = .magnetic
    @State private var notched = 40.0
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
                appearancePanel
                delightPanel

                group("Notches") {
                    GlitchSegmented(
                        "Snapping",
                        selection: $notches,
                        options: GlitchNotchSnapping.allCases.map {
                            GlitchOption($0.title, value: $0)
                        }
                    )
                    GlitchSlider("Try it", value: $notched, notches: notches)
                    explain(notchExplanation)
                }

                group("Slider") {
                    GlitchSlider("Flow", value: $flow)
                    GlitchSlider("Fine", value: $flow, in: 0...1, step: 0.01)
                    // Ten steps or fewer, so every step gets its own notch and
                    // a click lands exactly on one.
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
    }

    private var appearancePanel: some View {
        GlitchPanel {
            GlitchSection("Appearance") {
                GlitchSegmented(
                    "Theme",
                    selection: $style,
                    options: GlitchThemeStyle.allCases.map { GlitchOption($0.title, value: $0) }
                )
                GlitchSegmented(
                    "Mode",
                    selection: $scheme,
                    options: [
                        GlitchOption("Dark", value: ColorScheme.dark),
                        GlitchOption("Light", value: ColorScheme.light),
                    ]
                )
                if style == .liquidGlass {
                    GlitchSegmented(
                        "Material",
                        selection: $glass,
                        options: GlitchGlassVariant.allCases.map {
                            GlitchOption($0.title, value: $0)
                        }
                    )
                }
                GlitchSegmented(
                    "Density",
                    selection: $density,
                    options: GlitchDensity.allCases.map { GlitchOption($0.title, value: $0) }
                )
                explain(styleExplanation)
            }
        }
    }

    private var delightPanel: some View {
        GlitchPanel {
            GlitchSection("Game feel") {
                GlitchToggle("Delight", isOn: $delight)
                explain(
                    delight
                    ? "On: hit-stop at the limits, a ghost of where a value came from, inertia in the fill, notches that light up before they pull, and panels that unroll. None of it changes which values you can reach."
                    : "Off: the same controls with every embellishment removed. Identical maths, identical reachable values — this is the plain professional version."
                )
            }
        }
    }

    private var styleExplanation: String {
        switch style {
        case .glitch:
            "Neutral white alphas over near-black. No colour does any signalling, so a panel of twenty controls stays legible."
        case .engineering:
            "Instrument-like: light chassis, black legends, one hot orange carrying every active state, and tight machined radii."
        case .film:
            "Almost nothing: no containers, no borders, no wells. A slider becomes a hairline with a dot on it and its caption on the line above — the interface getting out of the way of the work."
        case .liquidGlass:
            "Every surface is the platform's glass material, tinted by the same tokens the other styles fill with. Radii open right up — glass with tight corners reads as a chip of it."
        }
    }

    private var notchExplanation: String {
        switch notches {
        case .off:
            "Free movement — the value quantises to its step and nothing else. This is the reference panel's behaviour."
        case .magnetic:
            "Notches attract from within 2% of the range, and light up from 5% out — so the pull is always announced before it happens."
        case .locked:
            "Every drag lands on a notch. For values where the positions in between aren't meaningful."
        }
    }

    private func explain(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.metrics.labelSize))
            .foregroundStyle(theme.palette.labelSecondary)
            .fixedSize(horizontal: false, vertical: true)
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
    @Previewable @State var style = GlitchThemeStyle.glitch
    @Previewable @State var glass = GlitchGlassVariant.regular
    @Previewable @State var scheme = ColorScheme.dark
    @Previewable @State var density = GlitchDensity.compact
    @Previewable @State var delight = true

    GalleryView(
        style: $style, glass: $glass, scheme: $scheme,
        density: $density, delight: $delight
    )
    .glitchTheme(style, glass: glass, density: density)
    .glitchMotion()
    .glitchDelight(delight)
    .preferredColorScheme(scheme)
    .frame(width: 640, height: 800)
}
