import SwiftUI

/// Every knob the gooey field exposes. A plain value type, matching
/// `PathMenuStyle`'s approach: cheap to build, store, and hand to a demo.
public struct GlitchGooFieldStyle: Sendable {
    /// Blend range of the liquid union, in points. The gooeyness dial.
    public var goo: CGFloat = 14
    /// Surface-to-surface gap between the capsule and the detached button.
    public var detachDistance: CGFloat = 16
    /// Diameter of the submit button. Zero means "match the field height".
    public var buttonDiameter: CGFloat = 0
    /// Extra edge softness in points. Zero is a crisp antialiased edge.
    public var edgeSoftness: CGFloat = 0
    /// Spring for the bud-off travel. `nil` uses the theme's travel spring.
    public var spring: Spring? = nil
    /// Fill of the liquid. `nil` uses the palette's active track.
    public var tint: Color? = nil

    public init() {}
}

/// A capsule text field whose submit button buds off the trailing end when
/// focused, joined to the capsule by a stretching neck of liquid on the way.
///
/// Like `GlitchTextField`, the native `TextField` keeps its behaviour —
/// selection, input methods, the system keyboard — and loses only its
/// appearance. The liquid is drawn by the goo shader underneath; the layout
/// footprint is constant, with the trailing margin simply empty at rest, so
/// focusing never reflows the text or the neighbours.
public struct GlitchGooField: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.isEnabled) private var isEnabled

    @Binding private var text: String
    private let placeholder: String
    private let style: GlitchGooFieldStyle
    private let onSubmit: (String) -> Void

    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String = "",
        style: GlitchGooFieldStyle = .init(),
        onSubmit: @escaping (String) -> Void = { _ in }
    ) {
        self._text = text
        self.placeholder = placeholder
        self.style = style
        self.onSubmit = onSubmit
    }

    public var body: some View {
        let metrics = theme.metrics
        let height = metrics.rowHeight
        let button = style.buttonDiameter > 0 ? style.buttonDiameter : height
        let reach = style.detachDistance + button
        let spring = style.spring ?? motion.travelSpring

        HStack(spacing: 0) {
            TextField(
                "",
                text: $text,
                prompt: Text(placeholder).foregroundStyle(theme.palette.labelSecondary)
            )
            .textFieldStyle(.plain)
            .focusEffectDisabled()
            .font(GlitchType.value(theme))
            .foregroundStyle(theme.palette.label)
            .focused($isFocused)
            .onSubmit(submit)
            .padding(.horizontal, metrics.hInset)

            // The room the button detaches into. Present at rest too, so the
            // capsule's width — and the text inside it — never moves.
            Color.clear
                .frame(width: reach)
                .overlay(alignment: .trailing) { submitButton(diameter: button) }
        }
        .frame(height: height)
        .background {
            GooFieldSurface(
                progress: isFocused ? 1 : 0,
                buttonDiameter: button,
                detachDistance: style.detachDistance,
                smoothing: style.goo,
                edge: style.edgeSoftness,
                fill: style.tint ?? theme.palette.trackActive
            )
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .opacity(isEnabled ? 1 : 0.4)
        .animation(.spring(spring), value: isFocused)
    }

    private func submitButton(diameter: CGFloat) -> some View {
        Button(action: submit) {
            Image(systemName: "arrow.right")
                .font(.system(size: theme.metrics.iconSize, weight: .semibold))
                .foregroundStyle(theme.palette.label)
                .frame(width: diameter, height: diameter)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        // Rides the same spring as the blob it sits on, so icon and liquid
        // arrive together; hidden and untouchable while merged.
        .opacity(isFocused ? 1 : 0)
        // Trailing-aligned resting centre is capsule end + detach + radius;
        // merged it must sit at capsule end − radius, hence this exact slide.
        .offset(x: isFocused ? 0 : -style.detachDistance - diameter)
        .allowsHitTesting(isFocused)
        .accessibilityLabel("Submit")
    }

    private func submit() {
        guard !text.isEmpty else { return }
        GlitchHaptics.impact()
        GlitchSound.commit()
        onSubmit(text)
    }
}

/// The liquid underlay. `Animatable` over the detach progress, so the spring
/// the field applies drives the shader's blob positions frame by frame —
/// per-frame work is a uniform update, never layout.
struct GooFieldSurface: View, Animatable {
    var progress: CGFloat
    var buttonDiameter: CGFloat
    var detachDistance: CGFloat
    var smoothing: CGFloat
    var edge: CGFloat
    var fill: Color

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        GeometryReader { proxy in
            GooSurface(
                blobs: GooMath.fieldBlobs(
                    in: proxy.size,
                    buttonDiameter: buttonDiameter,
                    detachDistance: detachDistance,
                    progress: progress
                ),
                smoothing: smoothing,
                edge: edge,
                fill: fill
            )
        }
    }
}

#Preview("Goo field") {
    @Previewable @State var email = ""

    VStack(spacing: 24) {
        GlitchGooField(text: $email, placeholder: "Enter your email") { _ in }
        GlitchGooField(text: $email, placeholder: "Locked").disabled(true)
    }
    .padding(32)
    .frame(width: 380)
    .background(GlitchPalette.dark.background)
    .glitchTheme()
    .glitchMotion()
    .preferredColorScheme(.dark)
}
