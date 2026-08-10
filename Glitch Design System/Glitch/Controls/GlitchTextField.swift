import SwiftUI

/// A text field in the system's chrome.
///
/// The only control here that wraps a native one. Reimplementing selection,
/// input methods, autocorrect and the system keyboard would be strictly worse
/// than what the platform already does, so `TextField` keeps its behavior and
/// loses only its appearance.
public struct GlitchTextField: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.isEnabled) private var isEnabled

    private let label: String?
    @Binding private var text: String
    private let placeholder: String
    private let error: String?
    /// Whether to hold a row of space for the error message.
    ///
    /// Set by the initializer rather than by the presence of an error, because
    /// a message that appears by pushing everything below it down is a worse
    /// experience than one that fades into space already allotted.
    private let reservesErrorSpace: Bool
    private let accessory: GlitchLabelAccessory

    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    public init(
        _ label: String? = nil,
        text: Binding<String>,
        placeholder: String = "",
        accessory: GlitchLabelAccessory = .none
    ) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.error = nil
        self.reservesErrorSpace = false
        self.accessory = accessory
    }

    public init(
        _ label: String? = nil,
        text: Binding<String>,
        placeholder: String = "",
        error: String?,
        accessory: GlitchLabelAccessory = .none
    ) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.error = error
        self.reservesErrorSpace = true
        self.accessory = accessory
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            field
            if reservesErrorSpace {
                errorMessage
            }
        }
        .animation(motion.pop, value: error)
    }

    private var field: some View {
        let metrics = theme.metrics
        let shape = RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous)

        return HStack(spacing: metrics.spacing) {
            if let label {
                GlitchLabel(label, secondary: true, accessory: accessory)
            }
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
        }
        .padding(.horizontal, metrics.hInset)
        .frame(height: metrics.rowHeight)
        .glitchSurface(shape, fill: state.trackFill(theme.palette))
        .opacity(state.contentOpacity)
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .glitchHover { hovering in
            withAnimation(motion.snap) { isHovering = hovering }
        }
        .animation(motion.snap, value: isFocused)
    }

    private var errorMessage: some View {
        Text(error ?? "")
            .font(.system(size: theme.metrics.labelSize))
            .foregroundStyle(theme.palette.danger)
            .lineLimit(1)
            .padding(.horizontal, 2)
            .frame(height: theme.metrics.labelSize + 4, alignment: .leading)
            .opacity(error == nil ? 0 : 1)
            .offset(y: error == nil ? -3 : 0)
            .accessibilityHidden(error == nil)
    }

    private var state: ControlState {
        ControlState(
            isHovering: isHovering,
            isFocused: isFocused,
            isDisabled: !isEnabled,
            isErrored: error != nil
        )
    }
}

/// A text field with a magnifier and a clear button.
public struct GlitchSearchField: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.isEnabled) private var isEnabled

    @Binding private var text: String
    private let placeholder: String

    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    public init(text: Binding<String>, placeholder: String = "Search") {
        self._text = text
        self.placeholder = placeholder
    }

    public var body: some View {
        let metrics = theme.metrics
        let shape = RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous)

        HStack(spacing: metrics.spacing) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: metrics.iconSize, weight: .medium))
                .foregroundStyle(theme.palette.labelSecondary)

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
            .onKeyPress(.escape) {
                guard !text.isEmpty else { return .ignored }
                clear()
                return .handled
            }

            if !text.isEmpty {
                Button(action: clear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: metrics.iconSize))
                        .foregroundStyle(theme.palette.labelSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, metrics.hInset)
        .frame(height: metrics.rowHeight)
        .glitchSurface(shape, fill: state.trackFill(theme.palette))
        .opacity(state.contentOpacity)
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .glitchHover { hovering in
            withAnimation(motion.snap) { isHovering = hovering }
        }
        .animation(motion.pop, value: text.isEmpty)
        .animation(motion.snap, value: isFocused)
    }

    private func clear() {
        text = ""
        isFocused = true
        GlitchHaptics.selection()
    }

    private var state: ControlState {
        ControlState(isHovering: isHovering, isFocused: isFocused, isDisabled: !isEnabled)
    }
}

#Preview("Text fields") {
    @Previewable @State var name = "Felix"
    @Previewable @State var email = "not-an-email"
    @Previewable @State var query = ""

    VStack(spacing: 10) {
        GlitchTextField("Name", text: $name, placeholder: "Your name")
        GlitchTextField(
            "Email",
            text: $email,
            placeholder: "you@example.com",
            error: email.contains("@") ? nil : "Needs an @"
        )
        GlitchSearchField(text: $query)
        GlitchTextField("Locked", text: $name).disabled(true)
    }
    .padding(24)
    .frame(width: 340)
    .background(GlitchPalette.dark.background)
    .glitchTheme()
    .preferredColorScheme(.dark)
}
