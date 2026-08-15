import SwiftUI

// MARK: - Trigger

/// What makes the submit button separate from the field.
public enum GlitchGooFieldTrigger: String, CaseIterable, Hashable, Sendable, Identifiable {
    /// On focus, as in the reference. The button is there while you are typing
    /// and gone when you are not.
    case focus
    /// Once there is something to submit. Arguably the more useful of the two:
    /// an empty field has nothing for the button to do.
    case nonEmpty
    /// Always shed. For a field that is the only thing on its screen.
    case always

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .focus: "On focus"
        case .nonEmpty: "When filled"
        case .always: "Always"
        }
    }
}

// MARK: - Field

/// A text field that sheds a submit button.
///
/// A sibling to `GlitchTextField` rather than a mode of it. The anatomy is
/// genuinely different — a capsule with an action separating out of its trailing
/// end, and no inline label row — and one control carrying both would spend its
/// life explaining which half you were talking to.
///
/// Like `GlitchTextField`, the platform `TextField` is wrapped rather than
/// rebuilt: selection, input methods, autocorrect and the system keyboard are
/// all strictly better than anything reimplemented here, so only the appearance
/// is replaced.
///
/// The merge is decoration. The goo draws behind two real views, and the field
/// submits identically whether it is merging, blurring, or drawing nothing at
/// all — which is what lets `.glitchDelight(false)` switch it off without
/// taking anything away.
public struct GlitchGooField: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.glitchGooStyle) private var gooStyle
    @Environment(\.glitchGooFieldStyle) private var fieldStyle
    @Environment(\.isEnabled) private var isEnabled

    @Binding private var text: String
    private let placeholder: String
    private let trigger: GlitchGooFieldTrigger
    private let submitImage: String
    private let reach: CGFloat
    private let onSubmit: () -> Void

    private var widthOverride: CGFloat?

    @FocusState private var isFocused: Bool
    @State private var isHovering = false

    public init(
        text: Binding<String>,
        placeholder: String = "",
        trigger: GlitchGooFieldTrigger = .focus,
        submitImage: String = "arrow.right",
        reach: CGFloat = 1.55,
        onSubmit: @escaping () -> Void = {}
    ) {
        self._text = text
        self.placeholder = placeholder
        self.trigger = trigger
        self.submitImage = submitImage
        self.reach = reach
        self.onSubmit = onSubmit
    }

    // MARK: Geometry

    private var height: CGFloat { theme.metrics.rowHeight * fieldStyle.heightScale }
    private var buttonDiameter: CGFloat { height * fieldStyle.buttonScale }
    private var fieldWidth: CGFloat { widthOverride ?? fieldStyle.width }
    private var geometry: GlitchGooFieldGeometry {
        GlitchGooFieldGeometry(
            fieldWidth: fieldWidth,
            fieldHeight: height,
            buttonDiameter: buttonDiameter,
            reach: reach,
            reservedReach: fieldStyle.reservedReach
        )
    }

    /// `0` merged into the capsule, `1` fully separated. One animatable number
    /// drives the button's travel and the shapes the goo is built from, so the
    /// blob cannot disagree with what is drawn on it.
    private var detachment: Double {
        guard isEnabled else { return 0 }
        return switch trigger {
        case .focus: isFocused ? 1 : 0
        case .nonEmpty: text.isEmpty ? 0 : 1
        case .always: 1
        }
    }

    public var body: some View {
        ZStack {
            goo
            capsule
            button
        }
        .frame(width: geometry.stageWidth, height: height + gooStyle.shadowRadius * 2)
        .scaleEffect(isHovering ? fieldStyle.hoverScale : 1, anchor: .leading)
        .opacity(isEnabled ? 1 : 0.4)
        .animation(motion.glide, value: detachment)
        .animation(motion.snap, value: isHovering)
    }

    // MARK: Goo

    /// The merged silhouette of the capsule and the button, drawn behind both.
    private var goo: some View {
        GlitchGooLayer(
            shapes: [
                .capsule(
                    center: CGPoint(x: geometry.capsuleCenterX, y: 0),
                    size: CGSize(width: fieldWidth, height: height)
                ),
                .circle(center: CGPoint(x: buttonOffset, y: 0), diameter: buttonDiameter),
            ],
            style: separatingStyle,
            fill: theme.palette.trackActive,
            size: CGSize(
                width: geometry.stageWidth + gooStyle.shadowRadius * 4,
                height: height + gooStyle.shadowRadius * 4
            ),
            phase: detachment
        )
    }

    /// The blend, opened up as the button leaves and closed to nothing at rest.
    ///
    /// A smooth minimum is always *less* than the hard one, so two shapes that
    /// deeply overlap push their shared surface outward — and at rest the button
    /// is inscribed in the capsule's trailing end, which bulged it into an egg.
    /// Scaling the blend by the separation removes the cause rather than
    /// compensating for it: at rest the merge is exactly `min`, which is exactly
    /// the capsule, and the neck only exists while there is something for it to
    /// join.
    private var separatingStyle: GlitchGooStyle {
        var style = gooStyle
        style.blend *= detachment
        return style
    }

    /// Where the button sits, relative to the stable stage centre. Reach moves
    /// the button. It does not resize the text field.
    private var buttonOffset: CGFloat { geometry.buttonCenterX(progress: detachment) }

    // MARK: Field

    private var capsule: some View {
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
        }
        .padding(.horizontal, theme.metrics.hInset * 1.4)
        .frame(width: fieldWidth, height: height)
        // Only the goo draws a surface. A second one here would show through it
        // as a seam wherever the two disagreed about their edges.
        .contentShape(Capsule())
        .onTapGesture { isFocused = true }
        .offset(x: geometry.capsuleCenterX)
        .glitchHover { hovering in
            withAnimation(motion.snap) { isHovering = hovering }
        }
    }

    // MARK: Button

    private var button: some View {
        Button(action: submit) {
            Image(systemName: submitImage)
                .font(.system(size: theme.metrics.iconSize, weight: .semibold))
                .foregroundStyle(theme.palette.label)
                .frame(width: buttonDiameter, height: buttonDiameter)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .offset(x: buttonOffset)
        // Below the point where it has cleared the capsule there is nothing to
        // aim at, so it neither takes the pointer nor announces itself.
        .opacity(detachment)
        .blur(radius: (1 - detachment) * fieldStyle.iconBlur)
        .animation(
            detachment > 0
                ? motion.tint.delay(fieldStyle.iconRevealDelay)
                : motion.tint,
            value: detachment
        )
        .allowsHitTesting(detachment > 0.9)
        .accessibilityHidden(detachment < 0.9)
        .accessibilityLabel("Submit")
    }

    private func submit() {
        if fieldStyle.dismissesOnSubmit {
            isFocused = false
        }
        GlitchHaptics.impact()
        GlitchSound.commit()
        onSubmit()
    }
}

// MARK: - Width

extension GlitchGooField {
    /// Sets the resting width of the capsule.
    ///
    /// The control is a fixed width rather than a greedy one because the goo has
    /// to be given a canvas large enough to hold the button once it has left,
    /// and a shape that has not been laid out yet cannot say how wide that is.
    public func glitchGooFieldWidth(_ width: CGFloat) -> Self {
        var copy = self
        copy.widthOverride = width
        return copy
    }
}

#Preview("Goo field") {
    @Previewable @State var email = ""
    @Previewable @State var filled = "felix@example.com"

    VStack(alignment: .leading, spacing: 20) {
        GlitchGooField(text: $email, placeholder: "Enter your email")
        GlitchGooField(text: $filled, placeholder: "Enter your email", trigger: .nonEmpty)
        GlitchGooField(text: $filled, placeholder: "Locked").disabled(true)
    }
    .padding(40)
    .background(GlitchPalette.dark.background)
    .glitchTheme()
    .glitchMotion()
    .preferredColorScheme(.dark)
}
