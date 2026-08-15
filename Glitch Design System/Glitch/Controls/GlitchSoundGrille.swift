import SwiftUI

/// How the output readout is drawn.
///
/// The reading is identical in all four — lit means loud, and the lit portion
/// grows with the level. Only the shape of the thing doing the reporting
/// changes, because a speaker looks like whatever the object around it is
/// made of.
public enum GlitchGrilleStyle: String, CaseIterable, Sendable, Hashable {
    /// A round perforated grille, filling outward from the centre.
    case perforated
    /// A rectangular dot matrix, filling left to right. Panel hardware.
    case matrix
    /// A single hairline row of dots. Filled means on, hollow means muted.
    case dotted
    /// Concentric rings, lighting outward.
    case rings

    /// Which form a theme reaches for when the caller doesn't say.
    public static func `default`(for style: GlitchThemeStyle) -> GlitchGrilleStyle {
        switch style {
        case .glitch: .perforated
        case .engineering: .matrix
        case .film: .dotted
        case .liquidGlass: .rings
        }
    }

    public var title: String { rawValue.capitalized }
}

/// A speaker grille that reports, and can be poked.
///
/// It reports a value it does not own: volume is set elsewhere, by a knob, and
/// no gesture here will change it — dragging does nothing, and VoiceOver is
/// told this is a value rather than something adjustable.
///
/// Tapping *auditions* instead. Poking a speaker to hear how loud it is set is
/// what anyone does with a real one, and it answers the question the readout
/// can only approximate. What comes out is a random noise from a small
/// menagerie, because a test tone that is always the same note stops being
/// information after the second press.
///
/// It has to say two things at once, and says them in two different registers
/// so neither can be mistaken for the other:
///
/// - **How loud**, as how far the lit portion reaches. The boundary is
///   deliberately soft; a hard edge would read as a progress bar wearing a
///   costume.
/// - **Whether sound is on at all**, as a mute mark rather than as dimness.
///   Brightness alone is ambiguous at low volume, where "quiet" and "muted"
///   look nearly identical.
///
/// Nothing here animates on its own. An indicator that pulses forever draws
/// the eye away from whatever the person is actually adjusting, and this one
/// sits next to a knob they will be looking at — it moves only when poked, or
/// when the level it reports changes.
public struct GlitchSoundGrille: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion

    private let label: String?
    private let isOn: Bool
    private let volume: Double
    private let range: ClosedRange<Double>
    private let styleOverride: GlitchGrilleStyle?
    private let showsReadout: Bool

    /// How wide the lit edge fades, as a fraction of the whole.
    private let edgeSoftness: Double = 0.16

    @State private var pokeScale: CGFloat = 1
    @State private var holeBounce: CGFloat = 1
    @State private var floaters: [SoundFloater] = []

    /// - Parameter showsReadout: whether the numeric reading sits below the
    ///   face. Off where the grille is standing next to the knob that sets it
    ///   — the number is already on screen, and printing it twice makes the
    ///   pair read as two controls rather than one. The face keeps reporting
    ///   either way, and so does VoiceOver.
    public init(
        _ label: String? = "Output",
        isOn: Bool,
        volume: Double,
        in range: ClosedRange<Double> = 0...100,
        style: GlitchGrilleStyle? = nil,
        showsReadout: Bool = true
    ) {
        self.label = label
        self.isOn = isOn
        self.volume = volume
        self.range = range
        self.styleOverride = style
        self.showsReadout = showsReadout
    }

    private var style: GlitchGrilleStyle {
        styleOverride ?? .default(for: theme.style)
    }

    public var body: some View {
        VStack(spacing: 6) {
            face
                .scaleEffect(pokeScale)
                .contentShape(Rectangle())
                .onTapGesture(perform: poke)
                // Above the face rather than inside it, so a label can drift
                // clear of the grille without being clipped by it.
                .overlay(alignment: .center) {
                    ZStack {
                        ForEach(floaters) { floater in
                            SoundFloaterLabel(floater: floater)
                        }
                    }
                    .offset(y: -theme.metrics.rowHeight * 0.55)
                    .allowsHitTesting(false)
                }
            if let label {
                GlitchLabel(label, secondary: true)
            }
            if showsReadout {
                GlitchValueText(readout, value: isOn ? volume : nil)
                    .foregroundStyle(isOn ? theme.palette.label : theme.palette.labelSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "Output")
        .accessibilityValue(accessibilityReading)
        // A button, not an adjustable: pressing it auditions the level, it
        // does not change it. The distinction matters to anyone navigating by
        // voice, who would otherwise be offered increment and decrement
        // actions that quietly do nothing.
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Plays a test sound")
        .accessibilityAction(.default, poke)
    }

    /// Poke the speaker.
    ///
    /// Squashes first and springs back past its resting size, so the thing
    /// looks struck rather than merely resized — and only makes a noise if it
    /// is currently claiming to be switched on, or the readout and the room
    /// would be saying different things.
    private func poke() {
        GlitchHaptics.impact()

        withAnimation(motion.snap) { pokeScale = 0.9 }
        withAnimation(motion.pop.delay(0.06)) { pokeScale = 1 }

        // Assigned plainly rather than inside `withAnimation`, so each hole's
        // own delayed `.animation` drives it — that is what makes the swell
        // travel outward from the centre instead of the whole field pulsing
        // as one. A cone moves that way; a light bulb doesn't.
        holeBounce = 1.35
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(130))
            holeBounce = 1
        }

        // The word appears exactly when there was a sound to name it after —
        // `playful()` returns nil when the system is silent, so a muted grille
        // stays quiet in both senses.
        guard isOn, let noise = GlitchSound.playful() else { return }
        release(noise)
    }

    private func release(_ noise: String) {
        let floater = SoundFloater.random(noise)
        floaters.append(floater)
        // Rapid poking shouldn't accumulate a cloud.
        if floaters.count > 6 { floaters.removeFirst() }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1500))
            floaters.removeAll { $0.id == floater.id }
        }
    }

    // MARK: - Faces

    @ViewBuilder
    private var face: some View {
        switch style {
        case .perforated: perforated
        case .matrix: matrix
        case .dotted: dotted
        case .rings: rings
        }
    }

    /// Round, holed, filling outward — a speaker as most objects wear one.
    private var perforated: some View {
        let diameter = theme.metrics.rowHeight * 2.2
        let usableRadius = diameter * 0.38
        let dot = max(2, diameter * 0.055)
        let ringCount = 5

        return ZStack {
            plate(Circle())

            ForEach(0...ringCount, id: \.self) { ring in
                let radius = usableRadius * CGFloat(ring) / CGFloat(ringCount)
                // Six more per ring outward keeps the spacing roughly even
                // rather than crowding the middle.
                let count = ring == 0 ? 1 : ring * 6

                ForEach(0..<count, id: \.self) { index in
                    let angle = Double(index) / Double(count) * 2 * .pi
                    let position = Double(ring) / Double(ringCount)

                    Circle()
                        .fill(colour(at: position))
                        .frame(width: dot, height: dot)
                        .scaleEffect(holeBounce)
                        .animation(motion.pop.delay(pokeDelay(position)), value: holeBounce)
                        .offset(x: cos(angle) * radius, y: sin(angle) * radius)
                }
            }

            muteMark(width: diameter * 0.86)
        }
        .frame(width: diameter, height: diameter)
        .animation(motion.glide, value: volume)
        .animation(motion.tint, value: isOn)
    }

    /// A rectangular matrix filling left to right, the way a panel meter does.
    /// Columns light as a unit, so the level is countable.
    private var matrix: some View {
        let width = theme.metrics.rowHeight * 2.6
        let height = theme.metrics.rowHeight * 1.3
        let columns = 11
        let rows = 5
        let dot = max(2, height * 0.11)

        return ZStack {
            plate(RoundedRectangle(cornerRadius: theme.metrics.controlRadius, style: .continuous))

            VStack(spacing: dot * 0.85) {
                ForEach(0..<rows, id: \.self) { _ in
                    HStack(spacing: dot * 0.85) {
                        ForEach(0..<columns, id: \.self) { column in
                            let position = Double(column) / Double(columns - 1)

                            Circle()
                                .fill(colour(at: position))
                                .frame(width: dot, height: dot)
                                .scaleEffect(holeBounce)
                                .animation(motion.pop.delay(pokeDelay(position)), value: holeBounce)
                        }
                    }
                }
            }

            muteMark(width: width * 0.86)
        }
        .frame(width: width, height: height)
        .animation(motion.glide, value: volume)
        .animation(motion.tint, value: isOn)
    }

    /// One hairline row. Filled dots mean sound; hollow ones mean muted —
    /// a mark drawn across a line this thin would be a line across a line.
    private var dotted: some View {
        let width = theme.metrics.rowHeight * 2.4
        let count = 15
        let dot = max(2, width * 0.030)

        return HStack(spacing: (width - dot * CGFloat(count)) / CGFloat(count - 1)) {
            ForEach(0..<count, id: \.self) { index in
                let position = Double(index) / Double(count - 1)

                Circle()
                    .strokeBorder(
                        isOn ? .clear : theme.palette.labelSecondary,
                        lineWidth: 1
                    )
                    .background {
                        Circle().fill(isOn ? colour(at: position) : .clear)
                    }
                    .frame(width: dot * 1.6, height: dot * 1.6)
                    .scaleEffect(holeBounce)
                    .animation(motion.pop.delay(pokeDelay(position)), value: holeBounce)
            }
        }
        .frame(width: width, height: theme.metrics.rowHeight * 0.6)
        .animation(motion.glide, value: volume)
        .animation(motion.tint, value: isOn)
    }

    /// Concentric rings rather than holes. Glass has no business pretending to
    /// be perforated metal, and a continuous form suits a continuous material.
    private var rings: some View {
        let diameter = theme.metrics.rowHeight * 2.2
        let ringCount = 5

        return ZStack {
            plate(Circle())

            ForEach(1...ringCount, id: \.self) { ring in
                let position = Double(ring) / Double(ringCount)
                let inset = diameter * 0.5 * (1 - CGFloat(position) * 0.78)

                Circle()
                    .strokeBorder(colour(at: position), lineWidth: max(1.5, diameter * 0.022))
                    .padding(inset)
                    .scaleEffect(holeBounce)
                    .animation(motion.pop.delay(pokeDelay(position)), value: holeBounce)
            }

            muteMark(width: diameter * 0.86)
        }
        .frame(width: diameter, height: diameter)
        .animation(motion.glide, value: volume)
        .animation(motion.tint, value: isOn)
    }

    // MARK: - Shared parts

    private func plate(_ shape: some Shape) -> some View {
        shape
            .fill(theme.palette.track)
    }

    /// The universal mute slash, drawn over everything so it cannot be
    /// mistaken for a merely dark grille.
    @ViewBuilder
    private func muteMark(width: CGFloat) -> some View {
        if !isOn {
            Capsule()
                .fill(theme.palette.labelSecondary)
                .frame(width: width, height: 1.5)
                .rotationEffect(.degrees(-45))
        }
    }

    // MARK: - Reading

    private var level: Double {
        isOn ? GlitchValueMath.normalize(volume, in: range) : 0
    }

    /// How long a hole waits before joining the swell, by how far out it sits.
    ///
    /// Derived from the stagger token rather than a literal, so it collapses
    /// to zero under Reduce Motion — where the whole field simply pulses at
    /// once, which is the right answer when travel is what's objectionable.
    private func pokeDelay(_ position: Double) -> Double {
        motion.staggerDelay * position * 4
    }

    /// How lit a position is: fully inside the level, fading across the edge,
    /// dark beyond it.
    ///
    /// Unlit parts stay visible rather than vanishing — a grille with gaps in
    /// it looks broken, where a dark hole looks like a hole.
    private func colour(at position: Double) -> Color {
        guard isOn else { return theme.palette.hashmark.opacity(0.5) }

        let brightness = GlitchValueMath.clamp(
            (level - position) / edgeSoftness + 1,
            to: 0...1
        )
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

// MARK: - The word that escapes

/// One flight path, rolled when the label is created.
///
/// Every dimension is randomised — where it drifts, how far it climbs, how far
/// it leans, how big it starts and ends, and how fast the whole thing runs.
/// The point is that two pokes never look the same: a decoration that replays
/// identically stops being noticed after the third time, and the whole reason
/// to put a word on screen is that someone keeps pressing the thing.
private struct SoundFloater: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let drift: CGFloat
    let rise: CGFloat
    let tilt: Double
    let startScale: CGFloat
    let endScale: CGFloat
    let speed: Double

    static func random(_ text: String) -> SoundFloater {
        SoundFloater(
            text: text,
            drift: .random(in: -28...28),
            rise: .random(in: -78...(-46)),
            tilt: .random(in: -18...18),
            startScale: .random(in: 0.55...0.8),
            // Ending larger than it started is what sells "escaping" rather
            // than "receding".
            endScale: .random(in: 1.05...1.35),
            speed: .random(in: 0.85...1.25)
        )
    }
}

private struct SoundFloaterLabel: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion

    let floater: SoundFloater

    @State private var hasFlown = false
    @State private var hasFaded = false

    var body: some View {
        Text(floater.text)
            // Smaller than a readout: this is an aside, and it is competing
            // with the control it just came out of.
            .font(.system(
                size: max(8, theme.metrics.labelSize - 3),
                weight: .semibold,
                design: .monospaced
            ))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(Capsule().fill(.black.opacity(0.4)))
            .scaleEffect(hasFlown ? floater.endScale : floater.startScale)
            .rotationEffect(.degrees(hasFlown ? floater.tilt : 0))
            .offset(x: hasFlown ? floater.drift : 0, y: hasFlown ? floater.rise : 0)
            .opacity(hasFaded ? 0 : 1)
            .onAppear {
                // Two animations rather than one: sharing the flight's curve
                // would fade the word out over the whole climb, and it needs
                // to be readable for the first half of it.
                withAnimation(motion.float.speed(floater.speed)) { hasFlown = true }
                withAnimation(motion.float.speed(floater.speed * 1.3).delay(0.22)) {
                    hasFaded = true
                }
            }
    }
}

#Preview("Grille styles") {
    @Previewable @State var volume = 70.0
    @Previewable @State var isOn = true

    VStack(spacing: 20) {
        HStack(alignment: .top, spacing: 24) {
            ForEach(GlitchGrilleStyle.allCases, id: \.self) { style in
                GlitchSoundGrille(style.title, isOn: isOn, volume: volume, style: style)
            }
        }
        GlitchSlider("Volume", value: $volume)
        GlitchToggle("Sound", isOn: $isOn)
    }
    .padding(28)
    .frame(width: 620)
    .background(GlitchPalette.dark.background)
    .glitchTheme()
    .preferredColorScheme(.dark)
}
