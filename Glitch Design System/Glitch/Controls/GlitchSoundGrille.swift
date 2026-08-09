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

/// A speaker grille that reports, and never asks.
///
/// Display only: no gesture, no focus and no accessibility action, because a
/// readout that could also be dragged would invite people to try — and a
/// control that ignores a drag is worse than one that never offered. Volume is
/// set elsewhere, by a knob.
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
/// sits next to a knob they will be looking at.
public struct GlitchSoundGrille: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion

    private let label: String?
    private let isOn: Bool
    private let volume: Double
    private let range: ClosedRange<Double>
    private let styleOverride: GlitchGrilleStyle?

    /// How wide the lit edge fades, as a fraction of the whole.
    private let edgeSoftness: Double = 0.16

    public init(
        _ label: String? = "Output",
        isOn: Bool,
        volume: Double,
        in range: ClosedRange<Double> = 0...100,
        style: GlitchGrilleStyle? = nil
    ) {
        self.label = label
        self.isOn = isOn
        self.volume = volume
        self.range = range
        self.styleOverride = style
    }

    private var style: GlitchGrilleStyle {
        styleOverride ?? .default(for: theme.style)
    }

    public var body: some View {
        VStack(spacing: 6) {
            face
            if let label {
                GlitchLabel(label, secondary: true)
            }
            GlitchValueText(readout, value: isOn ? volume : nil)
                .foregroundStyle(isOn ? theme.palette.label : theme.palette.labelSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "Output")
        .accessibilityValue(accessibilityReading)
        // Explicitly not adjustable and not a button: this reports a value
        // that lives somewhere else, and VoiceOver should say so rather than
        // offer to change it here.
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
                    Circle()
                        .fill(colour(at: Double(ring) / Double(ringCount)))
                        .frame(width: dot, height: dot)
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
                            Circle()
                                .fill(colour(at: Double(column) / Double(columns - 1)))
                                .frame(width: dot, height: dot)
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
            .overlay {
                shape.stroke(
                    theme.metrics.tracksAreOutlined ? theme.palette.stroke : .clear,
                    lineWidth: theme.metrics.borderWidth
                )
            }
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
