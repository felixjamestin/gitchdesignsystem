import SwiftUI

/// What follows a control's title.
///
/// Two jobs that look the same and behave nothing alike. `icon` is a glyph the
/// title happens to want — a category mark, a warning, a link to something —
/// and is silent and unhittable. `info` is a control: it holds an explanation
/// that would clutter the row if it were always on screen, and hands it over
/// when asked.
///
/// A control-level parameter rather than an environment value, because a row
/// may draw more than one label — a radio group labels every option — and an
/// ambient accessory would attach itself to all of them.
public enum GlitchLabelAccessory: Equatable, Sendable {
    case none

    /// A decorative SF Symbol. Hidden from accessibility: the title beside it
    /// already says whatever it is saying.
    case icon(String)

    /// A symbol that reveals `text` when asked — tapped anywhere, and also
    /// hovered where there is a pointer.
    case info(String, symbol: String = "info.circle")

    /// The explanation, where there is one.
    ///
    /// Most rows in this system flatten their accessibility tree with
    /// `children: .ignore`, which is right — a slider should be one element,
    /// not five — but it also swallows the info control, leaving a screen
    /// reader no route to the text. So the control lifts it out and offers it
    /// as its own hint instead, which is a better reading of the same
    /// information: the explanation belongs to the setting, not to the glyph.
    public var infoText: String? {
        if case .info(let text, _) = self { return text }
        return nil
    }
}

// MARK: - Hoisting

/// A tooltip that wants drawing, and where its glyph is.
///
/// The tooltip cannot be drawn where it is asked for. Controls in this system
/// clip themselves — a segmented row clips so its pill cannot escape the track,
/// a slider clips so the fill stays inside the rounded ends — and a tooltip
/// rendered inside one of those is sliced off at the row's edge. Two separate
/// attempts to overlay it next to the glyph failed on exactly that.
///
/// So the glyph publishes a request and its position, and something further out
/// draws it. `Anchor<CGRect>` is what makes this work: the coordinates are
/// resolved by whichever ancestor ends up doing the drawing, so neither side
/// has to know how far apart they are.
struct GlitchTooltipRequest: Equatable {
    var text: String
    var anchor: Anchor<CGRect>
}

struct GlitchTooltipKey: PreferenceKey {
    static let defaultValue: GlitchTooltipRequest? = nil

    /// First one wins. Only one tooltip is ever open — showing one dismisses
    /// the others — so a second request in the same tree means two are
    /// mid-transition, and the one already there should finish.
    static func reduce(
        value: inout GlitchTooltipRequest?,
        nextValue: () -> GlitchTooltipRequest?
    ) {
        value = value ?? nextValue()
    }
}

private struct GlitchTooltipLayer: ViewModifier {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion

    func body(content: Content) -> some View {
        content
            .overlayPreferenceValue(GlitchTooltipKey.self) { request in
                GeometryReader { proxy in
                    if let request {
                        let glyph = proxy[request.anchor]
                        let gap = theme.metrics.spacing

                        GlitchTooltip(text: request.text)
                            // Caps the wrap width. An unbounded `fixedSize()`
                            // here once let the text measure single-line and
                            // re-wrap later, so bubble and text disagreed
                            // about the line count and the text escaped the
                            // bubble. A plain width proposal keeps the two in
                            // the same layout pass.
                            .frame(
                                maxWidth: GlitchTooltip.maximumWidth,
                                alignment: .bottomLeading
                            )
                            // Pushed right to sit under its glyph, then held
                            // back from the trailing edge so a tooltip on a
                            // right-hand control doesn't hang off the panel.
                            .padding(.leading, leading(for: glyph, in: proxy.size))
                            // A box ending just above the glyph, with the
                            // tooltip sitting at the bottom of it — which puts
                            // the tooltip's own bottom edge there without
                            // anyone having to measure its height.
                            .frame(
                                width: proxy.size.width,
                                height: max(0, glyph.minY - gap),
                                alignment: .bottomLeading
                            )
                            .transition(
                                .offset(y: 8)
                                .combined(with: .opacity)
                                .animation(motion.drift)
                            )
                    }
                }
                .allowsHitTesting(false)
            }
            // Consumed here. Without this a nested layer and an outer one would
            // both draw the same tooltip, one behind the other.
            .transformPreference(GlitchTooltipKey.self) { $0 = nil }
    }

    private func leading(for glyph: CGRect, in size: CGSize) -> CGFloat {
        let maximum = max(0, size.width - GlitchTooltip.maximumWidth)
        return min(max(0, glyph.minX), maximum)
    }
}

extension View {
    /// Draws any tooltip opened inside this subtree, at this level.
    ///
    /// `GlitchPanel` applies this already, so controls in a panel need nothing.
    /// Apply it yourself around controls used loose — without a layer somewhere
    /// above them, an info control has nowhere to put its tooltip and opening
    /// one does nothing visible.
    ///
    /// Put it outside anything that clips. Inside `GlitchSection` it would be
    /// cropped to the section, which is the problem it exists to solve.
    public func glitchTooltipLayer() -> some View {
        modifier(GlitchTooltipLayer())
    }
}

// MARK: - The tooltip

/// The explanation itself: a small slab that arrives from below.
///
/// Enters on `drift` — a spring with enough bounce to look like it landed
/// rather than appeared — travelling up into place. Under Reduce Motion the
/// token flattens to a short curve on its own, so the entrance becomes a fade
/// with no special-casing here.
///
/// Deliberately not a `.popover`. A popover would escape every clip for free,
/// which is the hard part solved, but it brings the system's own
/// scale-from-anchor transition and its own chrome — and the motion is the
/// point.
struct GlitchTooltip: View {
    @Environment(\.glitchTheme) private var theme

    /// Wide enough for a sentence or two, narrow enough to stay a tooltip
    /// rather than becoming a paragraph.
    static let maximumWidth: CGFloat = 220

    let text: String

    var body: some View {
        let metrics = theme.metrics

        Text(text)
            .font(GlitchType.label(theme))
            .foregroundStyle(theme.palette.textPrimary)
            .multilineTextAlignment(.leading)
            // Wraps at whatever width the layer proposes and takes the height
            // that wrapping needs; the bubble is then simply the padded
            // bounds of the result. No second measurement to disagree with.
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, max(metrics.hInset, 12))
            .padding(.vertical, max(metrics.hInset * 0.7, 8))
            .background {
                let shape = RoundedRectangle(
                    cornerRadius: metrics.controlRadius,
                    style: .continuous
                )
                // Two layers, because one is not reliably enough. `panel` is
                // the same colour as `background` in the film style, so a
                // tooltip over a panel would be invisible; `trackActive` on
                // top of it guarantees a step in tone against whatever it
                // covers, in every style.
                shape
                    .fill(theme.palette.panel)
                    .overlay { shape.fill(theme.palette.trackActive) }
                    .shadow(color: .black.opacity(0.28), radius: 12, y: 4)
            }
            // Read out by the control's accessibility hint instead, so a screen
            // reader hears the explanation once rather than twice.
            .accessibilityHidden(true)
    }
}

// MARK: - The glyph

/// The accessory glyph, and — for `info` — the state behind its tooltip.
struct GlitchLabelAccessoryView: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.isEnabled) private var isEnabled

    let accessory: GlitchLabelAccessory
    /// Overridden by the slider, which draws this twice: once in the label
    /// colour and once in `onFill`, masked to the filled region, so the glyph
    /// inverts along with the word it belongs to.
    var colour: Color?
    /// False for a decorative duplicate, so only one copy is hittable.
    var interactive: Bool = true

    @State private var showsTooltip = false
    @State private var dismissTask: Task<Void, Never>?

    /// Long enough to read a sentence, short enough that one opened by a stray
    /// tap doesn't sit there. Tapping again closes it sooner.
    private let visibleDuration: Duration = .seconds(6)

    var body: some View {
        switch accessory {
        case .none:
            EmptyView()

        case .icon(let symbol):
            glyph(symbol)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

        case .info(let text, let symbol):
            glyph(symbol)
                .opacity(showsTooltip ? 1 : 0.7)
                .contentShape(Rectangle())
                .allowsHitTesting(interactive)
                // High priority, not `.onTapGesture`. Most rows claim their
                // whole width with a press gesture — `glitchPressable` uses a
                // zero-distance drag, the slider a drag of its own — and a
                // plain child tap leaves it to SwiftUI's parent/child ordering
                // whether asking for help also flips the switch it belongs to.
                .highPriorityGesture(
                    interactive ? TapGesture().onEnded { toggle() } : nil
                )
                .glitchHover { hovering in
                    // Pointer platforms only: `isHovering` never becomes true
                    // on touch, so this is inert there and the tap is the whole
                    // interaction.
                    guard interactive else { return }
                    if hovering { show() } else { hide() }
                }
                .anchorPreference(key: GlitchTooltipKey.self, value: .bounds) { anchor in
                    showsTooltip
                        ? GlitchTooltipRequest(text: text, anchor: anchor)
                        : nil
                }
                .animation(motion.tint, value: showsTooltip)
                .accessibilityLabel("More information")
                .accessibilityHint(text)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { toggle() }
                .onDisappear { dismissTask?.cancel() }
        }
    }

    private func glyph(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: theme.metrics.iconSize * 0.85, weight: .medium))
            .foregroundStyle(colour ?? theme.palette.labelSecondary)
    }

    private func toggle() {
        guard isEnabled else { return }
        if showsTooltip { hide() } else { show() }
    }

    private func show() {
        guard isEnabled, !showsTooltip else { return }
        withAnimation(motion.drift) { showsTooltip = true }
        GlitchSound.tick()

        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: visibleDuration)
            guard !Task.isCancelled else { return }
            hide()
        }
    }

    private func hide() {
        dismissTask?.cancel()
        dismissTask = nil
        guard showsTooltip else { return }
        withAnimation(motion.snap) { showsTooltip = false }
    }
}

#Preview("Accessories") {
    @Previewable @State var loop = true
    @Previewable @State var gain = 0.4

    GlitchPanel {
        GlitchSection("Accessories") {
            GlitchToggle("Loop", isOn: $loop, accessory: .icon("repeat"))
            GlitchToggle(
                "Bypass",
                isOn: $loop,
                accessory: .info("Skips the effect chain without unloading it.")
            )
            GlitchSlider(
                "Gain",
                value: $gain,
                in: 0...1,
                step: 0.01,
                accessory: .info("Applied after the limiter, so it can clip.")
            )
        }
    }
    .padding(24)
    .frame(width: 340)
    .background(GlitchPalette.dark.background)
    .glitchTheme()
    .preferredColorScheme(.dark)
}
