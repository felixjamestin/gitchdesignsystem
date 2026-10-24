import SwiftUI

/// Where a press came from, so pointer and keyboard holds cannot complete or cancel each other.
public enum GlitchPressSource: Sendable {
    case pointer, keyboard, accessibility
}

/// One hold at a time: the first source to press owns it until it is released or cancelled.
public struct GlitchHoldPress: Equatable, Sendable {
    public private(set) var source: GlitchPressSource?
    public private(set) var startedAt: TimeInterval?
    public private(set) var completed = false

    public init() {}

    public mutating func begin(_ source: GlitchPressSource, now: TimeInterval) -> Bool {
        guard self.source == nil else { return false }
        self.source = source
        startedAt = now
        completed = false
        return true
    }

    public mutating func complete(now: TimeInterval, duration: TimeInterval) -> Bool {
        guard source != nil, !completed, let startedAt, now - startedAt >= duration else { return false }
        completed = true
        return true
    }

    public mutating func release(_ source: GlitchPressSource) -> Bool {
        guard self.source == source else { return false }
        cancel()
        return true
    }

    public mutating func cancel() {
        source = nil
        startedAt = nil
        completed = false
    }
}

/// The moments a glass button gives feedback for, so an app can voice them in its own sound.
public enum GlitchGlassFeedback: Equatable, Sendable {
    case tap
    case holdStep(index: Int, count: Int)
    case holdComplete

    /// The design system's own sound: a commit on a tap and on a completed hold.
    @MainActor public static func glitchSound(_ event: GlitchGlassFeedback) {
        if case .holdStep = event { return }
        GlitchSound.commit()
    }
}

/// A liquid glass button that fires on a tap, or on a hold that fills it from the leading edge when `hold` is above zero.
public struct GlitchGlassButton: View {
    private let title: String
    private let hold: Double
    private let style: GlitchTextStyle
    private let padding: EdgeInsets
    private let foreground: Color
    private let fill: Color
    private let progressTint: Color
    private let glass: Glass
    private let shape: AnyShape
    private let pressScale: CGFloat
    private let holdTicks: Int
    private let keyboardPressed: Bool
    private let keyboardActivation: Int
    private let acceptsPointer: Bool
    private let acceptsKeyboard: Bool
    private let accessibilityHint: String?
    private let feedback: @MainActor (GlitchGlassFeedback) -> Void
    private let action: (GlitchPressSource) -> Void

    @State private var holdPress = GlitchHoldPress()
    @State private var progress: CGFloat = 0
    @State private var isHolding = false
    @State private var isCompleted = false
    @State private var holdStartedAt: TimeInterval?
    @State private var completionTask: Task<Void, Never>?
    @State private var tickTask: Task<Void, Never>?
    @State private var hintTask: Task<Void, Never>?

    public static let padding = EdgeInsets(top: GlitchSpace.s150, leading: GlitchSpace.s300,
                                           bottom: GlitchSpace.s150, trailing: GlitchSpace.s300)

    /// `keyboardPressed` holds the button while a shortcut key is down, and each change of `keyboardActivation` taps it.
    public init(
        _ title: String,
        hold: Double = 0,
        style: GlitchTextStyle = .button,
        padding: EdgeInsets = GlitchGlassButton.padding,
        foreground: Color = .white.opacity(0.4),
        fill: Color = .black,
        progressTint: Color = .white.opacity(0.2),
        glass: Glass = .clear,
        shape: AnyShape = AnyShape(Capsule()),
        pressScale: CGFloat = 0.95,
        holdTicks: Int = 5,
        keyboardPressed: Bool = false,
        keyboardActivation: Int = 0,
        acceptsPointer: Bool = true,
        acceptsKeyboard: Bool = true,
        accessibilityHint: String? = nil,
        feedback: @escaping @MainActor (GlitchGlassFeedback) -> Void = GlitchGlassFeedback.glitchSound,
        action: @escaping (GlitchPressSource) -> Void
    ) {
        self.title = title
        self.hold = hold
        self.style = style
        self.padding = padding
        self.foreground = foreground
        self.fill = fill
        self.progressTint = progressTint
        self.glass = glass
        self.shape = shape
        self.pressScale = pressScale
        self.holdTicks = max(holdTicks, 1)
        self.keyboardPressed = keyboardPressed
        self.keyboardActivation = keyboardActivation
        self.acceptsPointer = acceptsPointer
        self.acceptsKeyboard = acceptsKeyboard
        self.accessibilityHint = accessibilityHint
        self.feedback = feedback
        self.action = action
    }

    private var holds: Bool { hold > 0 }

    public var body: some View {
        label
            .gesture(TapGesture().onEnded { tap(.pointer) }, isEnabled: !holds)
            .simultaneousGesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in beginHold(.pointer) }
                .onEnded { _ in endHold(.pointer) }, isEnabled: holds)
            .scaleEffect(isHolding ? pressScale : 1)
            .onChange(of: keyboardPressed) { _, pressed in
                if pressed && holds && acceptsKeyboard { beginHold(.keyboard) } else { endHold(.keyboard) }
            }
            .onChange(of: keyboardActivation) {
                if !holds && acceptsKeyboard { tap(.keyboard) }
            }
            .onChange(of: hold) { reset() }
            .onChange(of: acceptsPointer) { if let source = holdPress.source, !accepts(source) { reset() } }
            .onChange(of: acceptsKeyboard) { if let source = holdPress.source, !accepts(source) { reset() } }
            #if os(macOS)
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in reset() }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in reset() }
            #endif
            .onDisappear(perform: reset)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityHint(accessibilityHint ?? "")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                guard accepts(.accessibility) else { return }
                if holds { beginHold(.accessibility) } else { tap(.accessibility) }
            }
    }

    private var label: some View {
        Text(title)
            .glitchFont(style)
            .foregroundStyle(foreground)
            .padding(padding)
            .background {
                ZStack(alignment: .leading) {
                    Rectangle().fill(fill.gradient.opacity(0.2))
                    if holds && !isCompleted {
                        GeometryReader { proxy in
                            Rectangle()
                                .fill(progressTint)
                                .clipShape(shape)
                                .frame(width: proxy.size.width * progress)
                                .transition(.opacity)
                        }
                    }
                }
            }
            .clipShape(shape)
            .contentShape(shape)
            .glassEffect(glass.interactive(), in: shape)
    }

    private func accepts(_ source: GlitchPressSource) -> Bool {
        source == .keyboard ? acceptsKeyboard : acceptsPointer
    }

    private func tap(_ source: GlitchPressSource) {
        guard accepts(source) else { return }
        reset()
        feedback(.tap)
        action(source)
    }

    private func beginHold(_ source: GlitchPressSource) {
        let now = ProcessInfo.processInfo.systemUptime
        guard accepts(source), holdPress.begin(source, now: now) else { return }
        isCompleted = false
        hintTask?.cancel()
        holdStartedAt = now
        progress = 0
        withAnimation(.default) { isHolding = true }
        withAnimation(.linear(duration: hold)) { progress = 1 }
        startTicks()
        completionTask?.cancel()
        completionTask = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(hold)) } catch { return }
            guard !Task.isCancelled, accepts(source) else { return }
            completeHold()
        }
    }

    private func completeHold() {
        guard holdPress.complete(now: ProcessInfo.processInfo.systemUptime, duration: hold),
              let source = holdPress.source else { return }
        tickTask?.cancel()
        holdStartedAt = nil
        withAnimation(.default) { isHolding = false }
        withAnimation(.easeInOut(duration: 0.2)) { isCompleted = true }
        feedback(.holdComplete)
        action(source)
    }

    private func endHold(_ source: GlitchPressSource) {
        guard holdPress.release(source) else { return }
        completionTask?.cancel()
        guard !isCompleted else { return }
        tickTask?.cancel()
        let elapsed = holdStartedAt.map { ProcessInfo.processInfo.systemUptime - $0 }
        holdStartedAt = nil
        withAnimation(.default) { isHolding = false }
        // A quick tap on a hold button lifts the fill a little, so the reader learns it wants a hold.
        if let elapsed, elapsed <= Self.quickTap { showHint() } else { withAnimation(.snappy) { progress = 0 } }
    }

    private func showHint() {
        hintTask?.cancel()
        withAnimation(.easeOut(duration: 0.1)) { progress = 0.18 }
        hintTask = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(0.12)) } catch { return }
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.22)) { progress = 0 }
        }
    }

    private func startTicks() {
        tickTask?.cancel()
        let count = holdTicks, step = hold / Double(count)
        tickTask = Task { @MainActor in
            for index in 0..<count {
                guard !Task.isCancelled else { return }
                feedback(.holdStep(index: index, count: count))
                guard index < count - 1 else { return }
                do { try await Task.sleep(for: .seconds(step)) } catch { return }
            }
        }
    }

    private func reset() {
        holdPress.cancel()
        isCompleted = false
        completionTask?.cancel()
        tickTask?.cancel()
        hintTask?.cancel()
        holdStartedAt = nil
        isHolding = false
        progress = 0
    }

    /// A release this soon after a press reads as a tap.
    static let quickTap: TimeInterval = 0.18
}

/// Glass buttons side by side that melt into each other as members come and go.
public struct GlitchGlassGroup<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content
    @Namespace private var namespace

    public init(spacing: CGFloat = GlitchGap.group, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        GlassEffectContainer(spacing: spacing) {
            HStack(spacing: spacing) { content }
        }
        .environment(\.glitchGlassNamespace, namespace)
    }
}

extension EnvironmentValues {
    @Entry var glitchGlassNamespace: Namespace.ID?
}

extension View {
    /// Names a member of a `GlitchGlassGroup`, so its glass morphs when it appears or leaves.
    public func glitchGlassID<ID: Hashable & Sendable>(_ id: ID) -> some View {
        modifier(GlitchGlassMember(id: id))
    }
}

private struct GlitchGlassMember<ID: Hashable & Sendable>: ViewModifier {
    let id: ID
    @Environment(\.glitchGlassNamespace) private var namespace

    @ViewBuilder func body(content: Content) -> some View {
        if let namespace { content.glassEffectID(id, in: namespace) } else { content }
    }
}

#Preview("Glass buttons") {
    GlitchGlassGroup {
        GlitchGlassButton("Hold to stop", hold: 0.5) { _ in }
        GlitchGlassButton("Skip") { _ in }
    }
    .padding(GlitchSpace.s400)
    .background(.indigo.gradient)
}
