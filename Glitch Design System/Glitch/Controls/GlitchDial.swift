import SwiftUI

/// How a dial is drawn.
///
/// Only the drawing changes. Every style shares one gesture, one set of
/// notches and one value pipeline — a knob that behaved differently depending
/// on its finish would be a different control wearing a costume.
public enum GlitchDialStyle: String, CaseIterable, Sendable, Hashable {
    /// A track arc with a filled progress arc and a spoke. The default reading.
    case arc
    /// Printed legend: numerals around the bezel, engraved ticks, a hard
    /// pointer line on a solid cap. Reads as a panel-mounted potentiometer.
    case printed
    /// A flat disc and a single hairline. Nothing else — no arc, no ticks.
    case minimal
    /// A luminous progress arc with radiating ticks that light as they pass.
    case halo

    /// Which drawing a theme reaches for when the caller doesn't say.
    ///
    /// A dial is the most decorative control in the set, so it is the one
    /// where a style's character shows most; leaving every theme on the same
    /// arc would waste that.
    public static func `default`(for style: GlitchThemeStyle) -> GlitchDialStyle {
        switch style {
        case .glitch: .arc
        case .engineering: .printed
        case .film: .minimal
        case .liquidGlass: .halo
        }
    }

    public var title: String { rawValue.capitalized }

    /// Printed styles need room around the bezel for their legend; minimal
    /// ones want to be small enough to read as a mark.
    var diameterMultiple: CGFloat {
        switch self {
        case .arc: 2.2
        case .printed: 2.9
        case .minimal: 2.0
        case .halo: 2.4
        }
    }
}

/// A rotary knob over a 270° arc.
///
/// Two gestures, reading the same pointer two different ways:
///
/// - **Dragging accumulates the rotation performed.** Reading the absolute
///   angle instead breaks the moment the pointer crosses the seam behind the
///   knob — the raw angle jumps by nearly a full turn and the value leaps its
///   whole range in one frame. `shortestDelta` collapses that to the small
///   rotation actually made.
/// - **Tapping reads the angle absolutely**, because a tap names a position
///   outright rather than describing a turn, and the mark animates round to
///   it. Which of the two a press turns out to be is decided by whether it
///   travelled more than a few points, the same way the slider tells a click
///   from a drag.
public struct GlitchDial: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.glitchDelight) private var delight
    @Environment(\.isEnabled) private var isEnabled

    private let label: String
    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let step: Double
    private let decimals: Int
    private let styleOverride: GlitchDialStyle?

    private let sweep = GlitchAngleMath.defaultSweep

    /// Travel beyond this many points turns a press into a rotation. Below it
    /// the press is a tap, and a tap means "put the mark here".
    private let rotateThreshold: CGFloat = 3

    @State private var isDragging = false
    @State private var isHovering = false
    @State private var didRotate = false
    @State private var lastPointerAngle: Double?
    @State private var center: CGPoint = .zero
    @State private var landPulse: CGFloat = 1
    @FocusState private var isFocused: Bool

    public init(
        _ label: String,
        value: Binding<Double>,
        in range: ClosedRange<Double> = 0...100,
        step: Double = 1,
        decimals: Int = 0,
        style: GlitchDialStyle? = nil
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.step = step
        self.decimals = decimals
        self.styleOverride = style
    }

    private var style: GlitchDialStyle {
        styleOverride ?? .default(for: theme.style)
    }

    public var body: some View {
        VStack(spacing: 6) {
            dial
            GlitchLabel(label, secondary: true)
            GlitchValueText(
                GlitchNumberParsing.format(value, decimals: decimals),
                value: value,
                animated: !isDragging
            )
            .foregroundStyle(theme.palette.label)
        }
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(GlitchNumberParsing.format(value, decimals: decimals))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: adjust(by: effectiveStep)
            case .decrement: adjust(by: -effectiveStep)
            @unknown default: break
            }
        }
    }

    // MARK: - Drawing

    private var dial: some View {
        let diameter = theme.metrics.rowHeight * style.diameterMultiple

        return ZStack {
            switch style {
            case .arc: arcFace(diameter)
            case .printed: printedFace(diameter)
            case .minimal: minimalFace(diameter)
            case .halo: haloFace(diameter)
            }
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .onGeometryChange(for: CGPoint.self) { proxy in
            CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
        } action: { center = $0 }
        .gesture(rotateGesture)
        .glitchHover { hovering in
            withAnimation(motion.snap) { isHovering = hovering }
        }
        .focusable(isEnabled)
        .focused($isFocused)
        .glitchFocusRing(isFocused: isFocused, radius: 999)
        .onKeyPress(keys: [.leftArrow, .rightArrow]) { press in
            guard isEnabled else { return .ignored }
            let magnitude = effectiveStep * (press.modifiers.contains(.shift) ? 10 : 1)
            adjust(by: press.key == .leftArrow ? -magnitude : magnitude)
            return .handled
        }
    }

    /// Track arc, progress arc, spoke, cap.
    private func arcFace(_ diameter: CGFloat) -> some View {
        let lineWidth = diameter * 0.10

        return ZStack {
            trackArc(lineWidth: lineWidth, inset: lineWidth / 2)
            progressArc(lineWidth: lineWidth, inset: lineWidth / 2, color: theme.palette.accent)

            cap(diameter * 0.62)
            spoke(length: diameter * 0.22, offset: -diameter * 0.20, width: 2.5)
        }
    }

    /// Numerals around the bezel and engraved ticks, in the manner of a
    /// panel-mounted pot. The legend is printed on the chassis, so it stays
    /// the label's colour throughout rather than lighting up.
    private func printedFace(_ diameter: CGFloat) -> some View {
        let capDiameter = diameter * 0.52
        let legendRadius = diameter * 0.44
        let tickRadius = diameter * 0.36

        return ZStack {
            ForEach(0..<legendCount, id: \.self) { index in
                let fraction = Double(index) / Double(legendCount - 1)

                Capsule()
                    .fill(theme.palette.hashmark)
                    .frame(width: 1.5, height: diameter * 0.05)
                    .offset(y: -tickRadius)
                    .rotationEffect(.radians(angle(atFraction: fraction)))

                Text(GlitchNumberParsing.format(
                    GlitchValueMath.denormalize(fraction, in: range),
                    decimals: 0
                ))
                .font(.system(size: max(7, theme.metrics.labelSize - 2), weight: .bold))
                .foregroundStyle(theme.palette.label)
                .offset(legendOffset(fraction: fraction, radius: legendRadius))
            }

            cap(capDiameter)
            spoke(length: capDiameter * 0.42, offset: -capDiameter * 0.22, width: 2.5)
        }
    }

    /// A disc and a line. The value is legible only from the pointer's angle,
    /// which is all a VSCO-flavoured control would offer.
    private func minimalFace(_ diameter: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(theme.palette.trackActive)
                .frame(width: diameter * 0.86, height: diameter * 0.86)
                .scaleEffect(isDragging ? 0.97 : (isHovering ? 1.02 : 1))
                .animation(motion.snap, value: isDragging)
                .animation(motion.snap, value: isHovering)

            spoke(length: diameter * 0.24, offset: -diameter * 0.28, width: 2)
        }
    }

    /// A luminous arc with radiating ticks that light as the value passes
    /// them — the one style where the notches are always drawn, since they
    /// are the ornament rather than a hint.
    private func haloFace(_ diameter: CGFloat) -> some View {
        let lineWidth = diameter * 0.09
        let arcInset = diameter * 0.17
        let tickRadius = diameter * 0.47
        let progress = GlitchValueMath.normalize(value, in: range)

        return ZStack {
            ForEach(0..<haloTickCount, id: \.self) { index in
                let fraction = Double(index) / Double(haloTickCount - 1)
                let isLit = fraction <= progress + 1e-9

                Capsule()
                    .fill(isLit ? theme.palette.accent : theme.palette.hashmark)
                    .frame(width: 1.5, height: diameter * 0.055)
                    .offset(y: -tickRadius)
                    .rotationEffect(.radians(angle(atFraction: fraction)))
                    .animation(motion.tint, value: isLit)
            }

            trackArc(lineWidth: lineWidth, inset: arcInset)
            progressArc(lineWidth: lineWidth, inset: arcInset, color: theme.palette.accent)
                // The glow is what separates a lit arc from a coloured one.
                .shadow(color: theme.palette.accent.opacity(delight ? 0.65 : 0), radius: 7)

            cap(diameter * 0.56)
            spoke(length: diameter * 0.14, offset: -diameter * 0.19, width: 3.5)
        }
    }

    // MARK: - Shared parts

    private func trackArc(lineWidth: CGFloat, inset: CGFloat) -> some View {
        Circle()
            .trim(from: 0, to: sweepFraction)
            .stroke(theme.palette.track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(startRotation)
            .padding(inset)
    }

    private func progressArc(lineWidth: CGFloat, inset: CGFloat, color: Color) -> some View {
        Circle()
            .trim(from: 0, to: sweepFraction * GlitchValueMath.normalize(value, in: range))
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(startRotation)
            .padding(inset)
    }

    private func cap(_ diameter: CGFloat) -> some View {
        Circle()
            .fill(theme.palette.trackActive)
            .frame(width: diameter, height: diameter)
            .overlay {
                Circle().strokeBorder(
                    theme.metrics.tracksAreOutlined ? theme.palette.stroke : .clear,
                    lineWidth: theme.metrics.borderWidth
                )
            }
            .scaleEffect(isDragging ? 0.94 : (isHovering ? 1.03 : 1))
            .animation(motion.snap, value: isDragging)
            .animation(motion.snap, value: isHovering)
    }

    /// The pointer. A spoke rather than a dot, so the angle is readable at a
    /// glance instead of having to be inferred from a position.
    ///
    /// Rotation is driven straight off the value, so animating the value
    /// sweeps the mark round to it — and because `glide` carries overshoot,
    /// the mark arrives, passes slightly, and settles, which is what makes a
    /// tapped destination look aimed at rather than assigned.
    private func spoke(length: CGFloat, offset: CGFloat, width: CGFloat) -> some View {
        Capsule()
            .fill(theme.palette.handle)
            .frame(width: width, height: length)
            .scaleEffect(landPulse)
            .offset(y: offset)
            .rotationEffect(.radians(GlitchAngleMath.angle(forValue: value, sweep: sweep, in: range)))
    }

    // MARK: - Geometry

    private var sweepFraction: CGFloat { CGFloat(sweep / (2 * .pi)) }

    /// Rotates the trimmed circle so its start sits at the arc's beginning,
    /// measured from straight up.
    private var startRotation: Angle { .radians(-(.pi / 2) - sweep / 2) }

    private func angle(atFraction fraction: Double) -> Double {
        fraction * sweep - sweep / 2
    }

    private func legendOffset(fraction: Double, radius: CGFloat) -> CGSize {
        let a = angle(atFraction: fraction)
        return CGSize(width: sin(a) * radius, height: -cos(a) * radius)
    }

    /// Eleven numerals, as on the reference instrument. Enough to read a
    /// position off the bezel without counting.
    private var legendCount: Int { 11 }
    private var haloTickCount: Int { 25 }

    private var effectiveStep: Double {
        step > 0 ? step : (range.upperBound - range.lowerBound) / 100
    }

    // MARK: - Input

    private var rotateGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                guard isEnabled else { return }

                let pointerAngle = pointerAngle(at: gesture.location)

                guard let previous = lastPointerAngle else {
                    isDragging = true
                    isFocused = true
                    lastPointerAngle = pointerAngle
                    return
                }

                // A press that hasn't travelled yet is still a candidate tap,
                // so it must not nudge the value on the way to becoming one.
                if !didRotate {
                    let travel = hypot(gesture.translation.width, gesture.translation.height)
                    guard travel > rotateThreshold else { return }
                    didRotate = true
                }

                let delta = GlitchAngleMath.shortestDelta(from: previous, to: pointerAngle)
                lastPointerAngle = pointerAngle

                let span = range.upperBound - range.lowerBound
                let next = GlitchValueMath.snap(
                    value + delta / sweep * span,
                    step: step,
                    in: range
                )
                guard next != value else { return }

                // Motion rule 7 — no spring under the finger.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { value = next }
                GlitchHaptics.tick()
                GlitchSound.tick()
            }
            .onEnded { gesture in
                // Order matters. The readout suppresses its digit roll while
                // `isDragging`, exactly as the fill does — so a tap has to
                // stop counting as a drag *before* the value changes, or the
                // number it lands on arrives with no animation at all.
                let wasTap = !didRotate
                isDragging = false
                didRotate = false
                lastPointerAngle = nil

                if wasTap {
                    jump(to: gesture.location)
                }
            }
    }

    /// Where a point sits on the dial, measured from straight up, clockwise
    /// positive — the same convention the value mapping uses.
    private func pointerAngle(at location: CGPoint) -> Double {
        atan2(Double(location.x - center.x), -Double(location.y - center.y))
    }

    /// A tap: put the mark where it was aimed.
    ///
    /// Dragging accumulates rotation because a turning gesture has no absolute
    /// angle worth reading. A tap is the opposite — it names a position
    /// outright — so this reads the angle absolutely and animates the mark
    /// round to it, arriving with the same overshoot every other committed
    /// value in the system does.
    ///
    /// Angles outside the arc's 270° clamp to the nearer bound, so a tap in
    /// the gap at the bottom means minimum or maximum rather than nothing.
    private func jump(to location: CGPoint) {
        guard isEnabled else { return }

        // The middle of the dial has no meaningful angle: a tap two points
        // from the centre would otherwise fling the value somewhere arbitrary
        // on the strength of a rounding error.
        let distance = hypot(
            Double(location.x - center.x),
            Double(location.y - center.y)
        )
        guard distance >= Double(center.x) * 0.3 else { return }

        let target = GlitchValueMath.snap(
            GlitchAngleMath.value(forAngle: pointerAngle(at: location), sweep: sweep, in: range),
            step: step,
            in: range
        )
        guard target != value else { return }

        withAnimation(motion.glide) { value = target }
        GlitchHaptics.selection()
        GlitchSound.commit()
        land()
    }

    /// The small swell the mark makes on arriving, matching the slider's
    /// handle squash.
    private func land() {
        guard delight else { return }
        withAnimation(motion.snap) { landPulse = 1.18 }
        withAnimation(motion.pop.delay(0.07)) { landPulse = 1 }
    }

    private func adjust(by delta: Double) {
        let next = GlitchValueMath.snap(value + delta, step: step, in: range)
        guard next != value else {
            GlitchHaptics.limit()
            GlitchSound.reject()
            return
        }
        withAnimation(motion.glide) { value = next }
        GlitchHaptics.tick()
        GlitchSound.commit()
        land()
    }
}

#Preview("Dial styles") {
    @Previewable @State var value = 70.0

    HStack(spacing: 24) {
        ForEach(GlitchDialStyle.allCases, id: \.self) { style in
            GlitchDial(style.title, value: $value, style: style)
        }
    }
    .padding(28)
    .background(GlitchPalette.dark.background)
    .glitchTheme()
    .preferredColorScheme(.dark)
}
