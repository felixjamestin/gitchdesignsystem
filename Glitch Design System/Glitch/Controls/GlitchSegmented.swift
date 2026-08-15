import SwiftUI

/// A row of mutually exclusive choices with a sliding pill.
///
/// The pill is one view moved between segments, not a per-segment highlight
/// cross-fading. Cross-fading discards the relationship between where the
/// selection was and where it went, which is the only reason to prefer a
/// segmented control over a select in the first place.
///
/// The first appearance is deliberately instant. Sliding the pill in from
/// wherever it happened to be initialised animates a change the user did not
/// make.
public struct GlitchSegmented<Value: Hashable>: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.glitchDelight) private var delight
    @Environment(\.isEnabled) private var isEnabled

    private let label: String?
    @Binding private var selection: Value
    private let options: [GlitchOption<Value>]
    private let accessory: GlitchLabelAccessory

    @Namespace private var pill
    @State private var hasAppeared = false
    @State private var isHovering = false
    /// Elongation of the pill along its slide. Set the instant a selection
    /// moves and relaxed over the same `glide` the travel uses, so the pill
    /// is stretched mid-flight and settled on arrival.
    @State private var pillStretch: CGFloat = 1

    public init(
        _ label: String? = nil,
        selection: Binding<Value>,
        options: [GlitchOption<Value>],
        accessory: GlitchLabelAccessory = .none
    ) {
        self.label = label
        self._selection = selection
        self.options = options
        self.accessory = accessory
    }

    public var body: some View {
        let metrics = theme.metrics
        let shape = RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous)

        HStack(spacing: metrics.spacing) {
            if let label {
                GlitchLabel(label, accessory: accessory)
                Spacer(minLength: 8)
            }
            segments
                .frame(maxWidth: label == nil ? .infinity : nil)
        }
        .padding(.leading, label == nil ? 0 : metrics.hInset)
        .frame(height: metrics.rowHeight)
        .glitchSurface(shape, fill: isHovering && isEnabled ? theme.palette.trackHover : theme.palette.track)
        .clipShape(shape)
        .opacity(isEnabled ? 1 : 0.4)
        .glitchHover { hovering in
            withAnimation(motion.tint) { isHovering = hovering }
        }
        // No `.animation` above the pill. One placed here — even scoped to
        // hover — installs itself for the whole subtree and wins over the
        // transaction the tap set up, so the pill would slide on `tint`'s
        // 150ms instead of `glide`'s 360ms and read as no animation at all.
        // The hover already carries its own `withAnimation`.
        .onAppear { hasAppeared = true }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label ?? "Options")
    }

    private var segments: some View {
        HStack(spacing: 0) {
            if options.isEmpty {
                GlitchLabel("No options", secondary: true)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(options) { option in
                    segment(for: option)
                }
            }
        }
        .padding(2)
        // The pill's animation lives here, next to the pill, keyed on the
        // thing that moves it — not on whatever transaction happened to be
        // in flight when the selection changed. Nothing above can override
        // it, and there is exactly one place to look when it misbehaves.
        //
        // Nil until the first layout has settled, so the pill never animates
        // in from wherever it was initialised.
        .animation(hasAppeared ? motion.glide : nil, value: selection)
    }

    private func segment(for option: GlitchOption<Value>) -> some View {
        let metrics = theme.metrics
        let isSelected = option.value == selection

        return ZStack {
            if isSelected {
                RoundedRectangle(cornerRadius: max(2, metrics.controlRadius - 2), style: .continuous)
                    .fill(theme.palette.selectionFill)
                    // Squash and stretch on the slide, conserving area: long
                    // and low while travelling, its own shape once landed.
                    .scaleEffect(x: pillStretch, y: 2 - pillStretch)
                    .matchedGeometryEffect(id: "pill", in: pill)
            }

            HStack(spacing: 4) {
                if let systemImage = option.systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: metrics.iconSize, weight: .medium))
                }
                GlitchType.labelText(option.title, theme)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? theme.palette.onSelection : theme.palette.label)
            .padding(.horizontal, 12)
            .animation(motion.tint, value: isSelected)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { select(option.value) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { select(option.value) }
    }

    /// Sets the value and nothing else.
    ///
    /// The animation is declared on `segments`, keyed on `selection` — using
    /// `withAnimation` here as well would put two answers in the codebase for
    /// one question, and the losing one would still be sitting there looking
    /// authoritative.
    ///
    /// `glide` is the token, for the reason a slider uses it on a click: the
    /// pill is travelling to a position you pointed at, and wants the same
    /// overshoot. `snap` is for state that changes in place — a toggle knob, a
    /// checkmark — where an overshoot has nowhere to go.
    private func select(_ value: Value) {
        guard isEnabled, value != selection else { return }
        selection = value
        if delight, hasAppeared {
            // Instantly long, relaxing on the same clock as the travel.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { pillStretch = GlitchDelightTuning.pillStretch }
            withAnimation(motion.glide) { pillStretch = 1 }
        }
        GlitchHaptics.selection()
        GlitchSound.tick()
    }
}

#Preview("Segmented") {
    @Previewable @State var blend = "add"
    @Previewable @State var align = "center"

    VStack(spacing: 6) {
        GlitchSegmented("Blend", selection: $blend, options: [
            GlitchOption("Add", value: "add"),
            GlitchOption("Screen", value: "screen"),
        ])
        GlitchSegmented(selection: $align, options: [
            GlitchOption("Left", value: "left"),
            GlitchOption("Center", value: "center"),
            GlitchOption("Right", value: "right"),
        ])
    }
    .padding(12)
    .frame(width: 280)
    .background(GlitchPalette.dark.panel)
    .glitchTheme()
    .preferredColorScheme(.dark)
}
