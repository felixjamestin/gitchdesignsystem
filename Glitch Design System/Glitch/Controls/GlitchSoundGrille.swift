import SwiftUI

/// A speaker grille that reports, and never asks.
///
/// Display only: it has no gesture, no focus and no accessibility action,
/// because a readout that could also be dragged would invite people to try —
/// and a control that ignores a drag is worse than one that never offered.
/// Volume is set elsewhere, by a knob.
///
/// It has to say two things at once, and says them in two different registers
/// so neither can be mistaken for the other:
///
/// - **How loud**, as how far the lit dots reach from the centre. A grille
///   fills outward the way a speaker gets louder, and the boundary is
///   deliberately soft — a hard edge would read as a progress bar bent into a
///   circle.
/// - **Whether sound is on at all**, as colour plus a slash. Brightness alone
///   would be ambiguous at low volume, where "quiet" and "muted" look nearly
///   identical; the slash is unmistakable at any level.
public struct GlitchSoundGrille: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.glitchDelight) private var delight

    private let label: String?
    private let isOn: Bool
    private let volume: Double
    private let range: ClosedRange<Double>

    /// Rings of holes, centre outward. Five reads as a grille rather than as a
    /// diagram, while staying countable enough that a level is legible.
    private let ringCount = 5
    /// How wide the lit edge fades, as a fraction of the radius.
    private let edgeSoftness: Double = 0.16

    public init(
        _ label: String? = "Output",
        isOn: Bool,
        volume: Double,
        in range: ClosedRange<Double> = 0...100
    ) {
        self.label = label
        self.isOn = isOn
        self.volume = volume
        self.range = range
    }

    public var body: some View {
        VStack(spacing: 6) {
            grille
            if let label {
                GlitchLabel(label, secondary: true)
            }
            GlitchValueText(readout, value: isOn ? volume : nil)
                .foregroundStyle(isOn ? theme.palette.label : theme.palette.labelSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "Output")
        .accessibilityValue(accessibilityReading)
        // Explicitly not an adjustable or a button: this reports a value that
        // lives somewhere else, and VoiceOver should say so rather than offer
        // to change it here.
    }

    // MARK: - Grille

    private var grille: some View {
        let diameter = theme.metrics.rowHeight * 2.2

        return ZStack {
            Circle()
                .fill(theme.palette.track)
                .overlay {
                    Circle().strokeBorder(
                        theme.metrics.tracksAreOutlined ? theme.palette.stroke : .clear,
                        lineWidth: theme.metrics.borderWidth
                    )
                }

            holes(diameter: diameter)
            pings(diameter: diameter)

            if !isOn {
                // The universal mute mark, drawn across everything so it can't
                // be confused with a dark grille.
                Capsule()
                    .fill(theme.palette.labelSecondary)
                    .frame(width: diameter * 0.86, height: 1.5)
                    .rotationEffect(.degrees(-45))
            }
        }
        .frame(width: diameter, height: diameter)
        .animation(motion.glide, value: volume)
        .animation(motion.tint, value: isOn)
    }

    /// The holes themselves, laid out in concentric rings.
    private func holes(diameter: CGFloat) -> some View {
        let usableRadius = diameter * 0.38
        let dot = max(2, diameter * 0.055)

        return ZStack {
            ForEach(0...ringCount, id: \.self) { ring in
                let radius = usableRadius * CGFloat(ring) / CGFloat(ringCount)
                // Six per ring outward keeps the spacing roughly even instead
                // of crowding the middle.
                let count = ring == 0 ? 1 : ring * 6

                ForEach(0..<count, id: \.self) { index in
                    let angle = Double(index) / Double(count) * 2 * .pi

                    Circle()
                        .fill(colour(forRing: ring))
                        .frame(width: dot, height: dot)
                        .offset(
                            x: cos(angle) * radius,
                            y: sin(angle) * radius
                        )
                }
            }
        }
    }

    /// Sonar rings leaving the grille while it's playing.
    ///
    /// The one part that moves, and the only unambiguous signal that sound is
    /// *currently* happening rather than merely enabled. Paused entirely when
    /// silent, so a muted indicator costs nothing per frame.
    @ViewBuilder
    private func pings(diameter: CGFloat) -> some View {
        let isAudible = isOn && level > 0.01 && delight

        TimelineView(.animation(paused: !isAudible)) { timeline in
            Canvas { context, size in
                guard isAudible else { return }

                let time = timeline.date.timeIntervalSinceReferenceDate
                let centre = CGPoint(x: size.width / 2, y: size.height / 2)
                // Louder pings leave more often, which is most of why the
                // motion reads as level rather than as decoration.
                let rate = 0.35 + level * 0.5

                for index in 0..<3 {
                    let phase = ((time * rate) + Double(index) / 3)
                        .truncatingRemainder(dividingBy: 1)
                    let radius = size.width * (0.30 + 0.20 * phase)
                    let fade = (1 - phase) * 0.45 * level

                    let rect = CGRect(
                        x: centre.x - radius,
                        y: centre.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    context.stroke(
                        Circle().path(in: rect),
                        with: .color(theme.palette.accent.opacity(fade)),
                        lineWidth: 1
                    )
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .allowsHitTesting(false)
    }

    // MARK: - Reading

    private var level: Double {
        isOn ? GlitchValueMath.normalize(volume, in: range) : 0
    }

    /// How lit a ring is: fully inside the level, fading across the edge, dark
    /// beyond it.
    private func colour(forRing ring: Int) -> Color {
        guard isOn else { return theme.palette.hashmark.opacity(0.5) }

        let distance = Double(ring) / Double(ringCount)
        let brightness = GlitchValueMath.clamp(
            (level - distance) / edgeSoftness + 1,
            to: 0...1
        )

        // Unlit holes stay visible rather than vanishing: a grille with gaps
        // in it looks broken, where a dark hole looks like a hole.
        return brightness <= 0
            ? theme.palette.hashmark
            : theme.palette.accent.opacity(0.25 + 0.75 * brightness)
    }

    private var readout: String {
        isOn ? GlitchNumberParsing.format(volume, decimals: 0) : "OFF"
    }

    private var accessibilityReading: String {
        isOn
            ? "Volume \(GlitchNumberParsing.format(volume, decimals: 0))"
            : "Muted"
    }
}

#Preview("Sound grille") {
    @Previewable @State var volume = 70.0
    @Previewable @State var isOn = true

    VStack(spacing: 20) {
        HStack(spacing: 28) {
            GlitchSoundGrille(isOn: isOn, volume: volume)
            GlitchDial("Volume", value: $volume)
        }
        GlitchToggle("Sound", isOn: $isOn)
    }
    .padding(28)
    .frame(width: 340)
    .background(GlitchPalette.dark.background)
    .glitchTheme()
    .preferredColorScheme(.dark)
}
