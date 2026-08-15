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
    /// Arms the gooey surface's container-level animator, for the same reason
    /// `PathMenuPetal` arms its own: a `KeyframeAnimator` plays when its trigger
    /// *changes*, and the menu is mounted at the moment it is told to open.
    @State private var armedRuntime: RuntimePhase?

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
                    if style.surface == .gooey {
                        if runtime == .collapsed {
                            collapsedGoo(style: style)
                        } else {
                            gooey(style: style, geometry: geometry)
                        }
                    } else if runtime != .collapsed {
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
            .onChange(of: runtime, initial: true) { _, phase in armedRuntime = phase }
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

    private func petals(
        style: PathMenuStyle,
        geometry: PathMenuGeometry,
        progressFor: ((Int) -> Double?)? = nil
    ) -> some View {
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
                externalProgress: progressFor?(entry.index),
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

    // MARK: Gooey

    /// The gooey surface: one timeline for the whole menu, and one silhouette
    /// built from where it says every petal is.
    ///
    /// This is the only surface that cannot let the petals animate themselves.
    /// A merged blob has to be drawn from all their positions at once, and a
    /// blob built from stale positions slides off the icons it is carrying — so
    /// here a single `KeyframeAnimator` runs at the container and `PathMenuClock`
    /// gives each petal its share of it. Still no layout per frame: the animated
    /// value reaches only `offset` and the shader's arguments.
    ///
    /// One difference worth knowing about. With `.classic` motion the overshoot
    /// lives in the path's own waypoints — far, then near, then end — so this
    /// reproduces it exactly. With `.spring` motion the overshoot came from each
    /// petal's own spring, and a shared clock cannot give every petal its own;
    /// the group springs instead, and the petals do not individually sail past
    /// their resting radius.
    private func gooey(style: PathMenuStyle, geometry: PathMenuGeometry) -> some View {
        let clock = PathMenuClock()
        let reversed = runtime == .closing || runtime == .collapsed
        let duration = reduceMotion ? 0.2 : style.duration

        return KeyframeAnimator(
            // A style change rebuilds the animator. Keep an open menu open
            // instead of returning every petal to the trigger while its state
            // still says Expanded.
            initialValue: runtime == .open ? 1.0 : 0.0,
            trigger: armedRuntime
        ) { master in
            ZStack {
                GlitchGooLayer(
                    shapes: gooShapes(at: master, clock: clock, reversed: reversed,
                                      duration: duration, style: style, geometry: geometry),
                    style: style.goo,
                    fill: gooFill(style: style),
                    size: gooCanvas(style: style),
                    phase: master
                )
                .opacity(runtime == .selecting ? 0 : 1)

                petals(
                    style: style,
                    geometry: geometry,
                    progressFor: { index in
                        // Selection plays out through each petal's own emphasis
                        // tracks, so the shared clock stops driving them.
                        guard runtime != .selecting else { return nil }
                        return clock.petalProgress(
                            master: master, index: index, count: count,
                            duration: duration, stagger: style.stagger, reversed: reversed
                        )
                    }
                )
            }
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                if let spring = style.motion.springParameters, !reduceMotion {
                    SpringKeyframe(
                        1.0,
                        duration: clock.totalDuration(count: count, duration: duration, stagger: style.stagger),
                        spring: Spring(response: spring.response, dampingRatio: spring.dampingRatio)
                    )
                } else {
                    LinearKeyframe(
                        1.0,
                        duration: clock.totalDuration(count: count, duration: duration, stagger: style.stagger),
                        timingCurve: .easeIn
                    )
                }
            }
        }
    }

    /// The merged silhouette's shapes at a point on the master clock.
    private func gooShapes(
        at master: Double,
        clock: PathMenuClock,
        reversed: Bool,
        duration: Double,
        style: PathMenuStyle,
        geometry: PathMenuGeometry
    ) -> [GlitchGooShape] {
        var shapes: [GlitchGooShape] = []

        if style.bondsTrigger {
            shapes.append(.circle(center: .zero, diameter: style.triggerDiameter))
        }

        for index in 0 ..< min(count, geometry.anchors.count) {
            let timeline = PetalTimeline.make(
                phase: petalPhase(for: nil, style: style),
                anchors: geometry.anchors[index],
                index: index,
                count: count,
                style: style,
                reduceMotion: reduceMotion
            )
            let progress = clock.petalProgress(
                master: master, index: index, count: count,
                duration: duration, stagger: style.stagger, reversed: reversed
            )
            let point = timeline.path.point(at: progress)
            shapes.append(
                .circle(
                    center: CGPoint(x: point.width, y: point.height),
                    diameter: style.petalDiameter
                )
            )
        }
        return shapes
    }

    /// Large enough to hold the petals at full reach, their shadows, and the
    /// blend that reaches past both.
    ///
    /// Stated rather than inherited: the menu's layout footprint is only its
    /// trigger, which is the same reason `scrimExtent` is an explicit number.
    private func gooCanvas(style: PathMenuStyle) -> CGSize {
        let extent = style.farRadius
            + style.petalDiameter / 2
            + style.goo.shadowRadius
            + style.goo.blend
        return CGSize(width: extent * 2, height: extent * 2)
    }

    /// The closed trigger uses the same single surface as the open menu. This
    /// lets trigger and petal content stay surface-free for the whole gooey
    /// variant, so no internal rings can be drawn over the merged silhouette.
    private func collapsedGoo(style: PathMenuStyle) -> some View {
        let padding = style.goo.shadowRadius + style.goo.blend
        let extent = style.triggerDiameter + padding * 2
        return GlitchGooLayer(
            shapes: [.circle(center: .zero, diameter: style.triggerDiameter)],
            style: style.goo,
            fill: gooFill(style: style),
            size: CGSize(width: extent, height: extent)
        )
    }

    private func gooFill(style: PathMenuStyle) -> Color {
        style.goo.fill ?? .white.opacity(0.12)
    }

    private func petalPhase(for id: Data.Element.ID?, style: PathMenuStyle) -> PetalMotionPhase {
        switch runtime {
        case .opening, .open:
            return .opening
        case .closing, .collapsed:
            return .closing
        case .selecting:
            return id != nil && id == selectedID ? .blowingUp : .shrinking
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
