import SwiftUI

/// Animation, slowed down enough to argue about.
///
/// The speed control is the whole point: springs are hard to judge at full
/// speed, and easy to judge at a tenth. Because every control reads its
/// animation from `GlitchMotion` in the environment, nothing here is
/// special-cased — the slider changes one environment value and the entire
/// system slows with it, including the controls on this screen.
struct MotionLabView: View {
    @Environment(\.glitchTheme) private var theme

    @Binding var motionScale: Double
    @Binding var forceReduceMotion: Bool

    @State private var toggled = true
    @State private var checked = false
    @State private var choice = "Two"
    @State private var segment = "b"
    @State private var value = 40.0
    @State private var expanded = true
    @State private var chips = ["one", "two", "three"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                controls
                specimens
                tokens
            }
            .padding(16)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(theme.palette.background)
    }

    private var controls: some View {
        GlitchPanel {
            GlitchSection("Speed") {
                GlitchSlider(
                    "Scale",
                    value: $motionScale,
                    in: 0.1...2,
                    step: 0.05,
                    decimals: 2
                )
                Text("Multiplies every spring's response. At 0.10× a press takes almost two seconds to settle, which is long enough to see the overshoot.")
                    .font(.system(size: theme.metrics.labelSize))
                    .foregroundStyle(theme.palette.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                GlitchDivider()

                GlitchToggle("Force Reduce Motion", isOn: $forceReduceMotion)
                Text("Collapses all four springs to a short ease-out. The system setting is honoured whether or not this is on — this can only add the behaviour, never remove it.")
                    .font(.system(size: theme.metrics.labelSize))
                    .foregroundStyle(theme.palette.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var specimens: some View {
        GlitchPanel {
            GlitchSection("Specimens") {
                GlitchSlider("Glide", value: $value)
                GlitchToggle("Snap", isOn: $toggled)
                GlitchCheckbox("Checkmark draw", isOn: $checked)
                GlitchSegmented(
                    "Sliding indicator",
                    selection: $segment,
                    options: [
                        GlitchOption("A", value: "a"),
                        GlitchOption("B", value: "b"),
                        GlitchOption("C", value: "c"),
                    ]
                )
                GlitchSelect(
                    "Pop",
                    selection: $choice,
                    options: GlitchOption.list(["One", "Two", "Three"])
                )
                GlitchChips("Removal", items: $chips)
                GlitchButton("Restore chips") {
                    chips = ["one", "two", "three"]
                }
            }
        }
    }

    private var tokens: some View {
        GlitchPanel {
            GlitchSection("Tokens", initiallyExpanded: false) {
                tokenRow("snap", "0.18 / 0.86", "presses, toggles, checkmarks")
                tokenRow("glide", "0.32 / 0.82", "values settling after a drag")
                tokenRow("pop", "0.28 / 0.68", "things arriving — slight overshoot")
                tokenRow("drift", "0.50 / 1.00", "disclosure, ambient — no overshoot")
            }
        }
    }

    private func tokenRow(_ name: String, _ numbers: String, _ use: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(name)
                .font(GlitchType.value(theme))
                .foregroundStyle(theme.palette.accent)
                .frame(width: 48, alignment: .leading)
            Text(numbers)
                .font(GlitchType.value(theme))
                .foregroundStyle(theme.palette.label)
                .frame(width: 80, alignment: .leading)
            Text(use)
                .font(.system(size: theme.metrics.labelSize))
                .foregroundStyle(theme.palette.labelSecondary)
            Spacer(minLength: 0)
        }
        .frame(height: theme.metrics.rowHeight * 0.8)
    }
}

#Preview {
    @Previewable @State var scale = 1.0
    @Previewable @State var reduce = false

    MotionLabView(motionScale: $scale, forceReduceMotion: $reduce)
        .glitchTheme()
        .glitchMotion(scale: scale, reduceMotion: reduce)
        .preferredColorScheme(.dark)
        .frame(width: 560, height: 800)
}
