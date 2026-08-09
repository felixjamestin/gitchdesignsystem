import SwiftUI

/// A radial "path" menu: a trigger that fans a ring of petals out around itself.
///
/// A SwiftUI replication of levey/AwesomeMenu, down to its radii, keyframe timings
/// and stagger, but expressed as offsets from the trigger rather than absolute
/// points inside a fixed-size view. The component's layout footprint is exactly its
/// trigger, so it drops into any layout and the petals draw outside that footprint.
///
/// ```swift
/// PathMenu(items: actions) { action in
///     perform(action)
/// } trigger: { phase in
///     Circle().overlay(Image(systemName: "plus"))
/// } item: { action, phase in
///     ActionPetal(action, highlighted: phase.isHighlighted)
/// }
/// ```
///
/// Performance: the menu stores only a phase. It re-evaluates when that phase
/// changes and never per frame — each petal runs its own keyframe timeline and
/// touches only draw-time modifiers, so an open, animating menu performs no layout.
/// A closed menu has no petals mounted at all.
public struct PathMenu<Data, ItemContent, TriggerContent>: View
where
    Data: RandomAccessCollection,
    Data.Element: Identifiable,
    ItemContent: View,
    TriggerContent: View
{

    // MARK: Inputs

    private let items: Data
    private let explicitStyle: PathMenuStyle?
    private let externalExpanded: Binding<Bool>?
    private let onSelect: (Data.Element) -> Void
    private let triggerBuilder: (PathMenuTriggerPhase) -> TriggerContent
    private let itemBuilder: (Data.Element, PathMenuItemPhase) -> ItemContent

    @Environment(\.pathMenuStyle) private var environmentStyle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: State

    /// The menu's whole state. Nothing else changes during an animation, which is
    /// what keeps per-frame work confined to the petals.
    private enum RuntimePhase: Hashable {
        case collapsed
        case opening
        case open
        case closing
        case selecting
    }

    @State private var runtime: RuntimePhase = .collapsed
    /// Set by the drag gesture. Kept separate from `hoveredID` because releasing a
    /// drag selects this one, whereas merely hovering must never select anything.
    @State private var dragTargetID: Data.Element.ID?
    @State private var hoveredID: Data.Element.ID?
    @State private var selectedID: Data.Element.ID?
    @State private var triggerSize: CGSize = .zero

    // MARK: Init

    public init(
        items: Data,
        style: PathMenuStyle? = nil,
        isExpanded: Binding<Bool>? = nil,
        onSelect: @escaping (Data.Element) -> Void,
        @ViewBuilder trigger: @escaping (PathMenuTriggerPhase) -> TriggerContent,
        @ViewBuilder item: @escaping (Data.Element, PathMenuItemPhase) -> ItemContent
    ) {
        self.items = items
        self.explicitStyle = style
        self.externalExpanded = isExpanded
        self.onSelect = onSelect
        self.triggerBuilder = trigger
        self.itemBuilder = item
    }

    // MARK: Derived

    private var style: PathMenuStyle { explicitStyle ?? environmentStyle }
    private var count: Int { items.count }
    private var isOpen: Bool { runtime == .opening || runtime == .open }

    private struct ResolvedItem: Identifiable {
        let index: Int
        let element: Data.Element
        var id: Data.Element.ID { element.id }
    }

    private var resolvedItems: [ResolvedItem] {
        items.enumerated().map { ResolvedItem(index: $0.offset, element: $0.element) }
    }

    private func geometry(for style: PathMenuStyle) -> PathMenuGeometry {
        PathMenuGeometry(
            count: count,
            nearRadius: style.nearRadius,
            endRadius: style.endRadius,
            farRadius: style.farRadius,
            wholeAngle: style.wholeAngle.radians,
            rotationOffset: style.rotationOffset.radians
        )
    }

    /// How long a full expand or collapse takes, last petal included.
    private func totalDuration(for style: PathMenuStyle) -> Double {
        if reduceMotion { return 0.2 }
        return style.duration + style.stagger * Double(max(count - 1, 0))
    }

    // MARK: Body

    public var body: some View {
        let style = self.style
        let geometry = geometry(for: style)

        glassContainer(style: style) {
            trigger(style: style, geometry: geometry)
                // Petals and scrim live in backgrounds so they draw beneath the
                // trigger — matching the original's `insertSubview:belowSubview:` —
                // and, more importantly, so neither contributes to the layout size.
                .background(alignment: .center) {
                    if runtime != .collapsed {
                        petals(style: style, geometry: geometry)
                    }
                }
                .background(alignment: .center) {
                    if style.dimsBackground, runtime != .collapsed {
                        scrim(style: style)
                    }
                }
        }
        .task(id: runtime) {
                await advance(style: style)
            }
            .onChange(of: externalExpanded?.wrappedValue) { _, newValue in
                guard let newValue else { return }
                if newValue, runtime == .collapsed { runtime = .opening }
                if !newValue, runtime == .open { runtime = .closing }
            }
            .sensoryFeedback(trigger: runtime) { _, phase in
                guard style.hapticsEnabled else { return nil }
                return switch phase {
                case .opening, .closing: .impact(weight: .light)
                default: nil
                }
            }
            .sensoryFeedback(trigger: selectedID) { _, newValue in
                guard style.hapticsEnabled, newValue != nil else { return nil }
                return .selection
            }
    }

    // MARK: Glass

    /// Wraps the menu in a `GlassEffectContainer` so that glass petals merge into one
    /// another, and into the trigger, as they pass close by.
    ///
    /// The container is only introduced when there is glass for it to coordinate.
    /// It was previously present unconditionally, to keep view identity stable when
    /// switching surface at runtime; measurement showed that is not worth paying for
    /// on every solid menu, and the only place the surface changes at runtime is the
    /// demo, where a remount is harmless.
    ///
    /// It does not affect layout: its content is the trigger, and the petals hang off
    /// that in a background.
    @ViewBuilder
    private func glassContainer(
        style: PathMenuStyle,
        @ViewBuilder content: () -> some View
    ) -> some View {
        #if os(visionOS)
        content()
        #else
        if #available(iOS 26.0, macOS 26.0, *), style.surface.isGlass {
            GlassEffectContainer(spacing: style.glassBlendSpacing) { content() }
        } else {
            content()
        }
        #endif
    }

    // MARK: Trigger

    @ViewBuilder
    private func trigger(style: PathMenuStyle, geometry: PathMenuGeometry) -> some View {
        let phase = PathMenuTriggerPhase(
            isExpanded: isOpen,
            progress: isOpen ? 1 : 0,
            rotation: style.rotatesTrigger && isOpen ? style.triggerRotation : .zero
        )
        let rotationAnimation: Animation? = reduceMotion
            ? nil
            : .easeInOut(duration: style.triggerDuration)

        triggerBuilder(phase)
            .rotationEffect(phase.rotation)
            .animation(rotationAnimation, value: isOpen)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { triggerSize = $0 }
            .contentShape(.rect)
            .gesture(triggerGesture(style: style, geometry: geometry))
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text("Menu"))
            .accessibilityValue(Text(isOpen ? "Expanded" : "Collapsed"))
            .accessibilityAction {
                setExpanded(!isOpen)
            }
    }

    /// One gesture handles tapping and dragging.
    ///
    /// Press opens the menu, dragging highlights whichever petal the finger is over,
    /// and releasing chooses it — the Path app's original one-gesture flow. Targets
    /// are resolved arithmetically against the cached anchors rather than by hit
    /// testing, so this works wherever the menu is placed.
    private func triggerGesture(style: PathMenuStyle, geometry: PathMenuGeometry) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard style.dragToSelect else { return }
                if runtime == .collapsed { setExpanded(true) }
                guard isOpen else { return }

                let point = CGSize(
                    width: value.location.x - triggerSize.width / 2,
                    height: value.location.y - triggerSize.height / 2
                )
                let target = nearestPetal(to: point, style: style, geometry: geometry)
                if dragTargetID != target { dragTargetID = target }
            }
            .onEnded { _ in
                if let id = dragTargetID {
                    dragTargetID = nil
                    select(id: id, style: style)
                } else if runtime == .collapsed {
                    setExpanded(true)
                } else if runtime == .open {
                    setExpanded(false)
                }
            }
    }

    private func nearestPetal(
        to point: CGSize,
        style: PathMenuStyle,
        geometry: PathMenuGeometry
    ) -> Data.Element.ID? {
        let tolerance = style.petalDiameter / 2 * style.dragTolerance
        var best: (id: Data.Element.ID, distance: CGFloat)?

        // Indexes `items` directly rather than going through `resolvedItems`, which
        // would allocate an array on every frame of the drag.
        for offset in 0 ..< min(count, geometry.anchors.count) {
            let distance = point.distance(to: geometry.anchors[offset].end)
            guard distance <= tolerance else { continue }
            if best == nil || distance < best!.distance {
                best = (items[items.index(items.startIndex, offsetBy: offset)].id, distance)
            }
        }
        return best?.id
    }

    // MARK: Petals

    private func petals(style: PathMenuStyle, geometry: PathMenuGeometry) -> some View {
        ForEach(resolvedItems) { entry in
            let itemPhase = PathMenuItemPhase(
                index: entry.index,
                isHighlighted: dragTargetID == entry.id || hoveredID == entry.id,
                isSelected: selectedID == entry.id,
                isExpanded: isOpen
            )
            PathMenuPetal(
                content: itemBuilder(entry.element, itemPhase),
                anchors: geometry.anchors[entry.index],
                index: entry.index,
                count: count,
                style: style,
                phase: petalPhase(for: entry.id, style: style),
                reduceMotion: reduceMotion,
                isInteractive: runtime == .open,
                onTap: { select(id: entry.id, style: style) },
                onHover: { hovering in
                    guard style.highlightsOnHover else { return }
                    if hovering {
                        hoveredID = entry.id
                    } else if hoveredID == entry.id {
                        hoveredID = nil
                    }
                }
            )
        }
    }

    private func petalPhase(for id: Data.Element.ID, style: PathMenuStyle) -> PetalMotionPhase {
        switch runtime {
        case .opening, .open:
            return .opening
        case .closing, .collapsed:
            return .closing
        case .selecting:
            return id == selectedID ? .blowingUp : .shrinking
        }
    }

    // MARK: Scrim

    private func scrim(style: PathMenuStyle) -> some View {
        Rectangle()
            .fill(style.dimColor)
            // The menu is only as large as its trigger, so the scrim cannot inherit
            // the screen's bounds and is sized explicitly instead.
            .frame(width: style.scrimExtent, height: style.scrimExtent)
            .opacity(isOpen ? 1 : 0)
            .animation(.easeInOut(duration: style.duration * 0.6), value: isOpen)
            .contentShape(.rect)
            .onTapGesture { setExpanded(false) }
            .allowsHitTesting(runtime == .open)
            .accessibilityHidden(true)
    }

    // MARK: Transitions

    /// Toggling is refused mid-animation, as in the original's `_isAnimating` guard.
    /// `KeyframeAnimator` cannot blend an interrupted timeline, so this also avoids
    /// petals snapping to their resting positions when a transition is reversed.
    private func setExpanded(_ expand: Bool) {
        if expand {
            guard runtime == .collapsed else { return }
            runtime = .opening
        } else {
            guard runtime == .open else { return }
            runtime = .closing
            // Petals stop being interactive as they leave, so their hover callbacks
            // never fire a final `false`. Clear it here instead.
            hoveredID = nil
        }
        externalExpanded?.wrappedValue = expand
    }

    private func select(id: Data.Element.ID, style: PathMenuStyle) {
        guard let element = items.first(where: { $0.id == id }) else { return }

        hoveredID = nil
        selectedID = id
        onSelect(element)

        guard style.closesOnSelect else {
            selectedID = nil
            return
        }
        // `.blowUp` explodes the chosen petal and shrinks the rest; the others just
        // travel home the usual way.
        runtime = style.selectionEffect == .blowUp ? .selecting : .closing
        externalExpanded?.wrappedValue = false
    }

    /// Advances the phase once the current animation has played out. Driven by
    /// structured concurrency rather than the original's main-thread `NSTimer`.
    private func advance(style: PathMenuStyle) async {
        switch runtime {
        case .opening:
            try? await Task.sleep(for: .seconds(totalDuration(for: style)))
            if runtime == .opening { runtime = .open }

        case .closing:
            try? await Task.sleep(for: .seconds(totalDuration(for: style)))
            if runtime == .closing {
                runtime = .collapsed
                selectedID = nil
            }

        case .selecting:
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.2 : style.duration))
            if runtime == .selecting {
                runtime = .collapsed
                selectedID = nil
            }

        case .collapsed, .open:
            break
        }
    }
}
