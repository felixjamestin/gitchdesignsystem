import SwiftUI

// MARK: - Motion

/// How petals travel between the trigger and their resting positions.
public enum PathMenuMotion: Hashable, Sendable {
    /// Faithful reproduction of the original `CAKeyframeAnimation`: the petal
    /// overshoots to `farRadius`, pulls back through `nearRadius`, then settles on
    /// `endRadius`, the whole timeline under a single ease-in curve.
    case classic

    /// The same resting geometry, driven by a spring. The overshoot comes from the
    /// spring rather than from hand-authored waypoints.
    case spring(response: Double, dampingRatio: Double)

    /// A pleasant default spring.
    public static let smoothSpring = PathMenuMotion.spring(response: 0.42, dampingRatio: 0.72)

    var springParameters: (response: Double, dampingRatio: Double)? {
        if case let .spring(response, dampingRatio) = self { (response, dampingRatio) } else { nil }
    }
}

// MARK: - Surface

/// Background treatment for the built-in petal and trigger visuals.
///
/// Liquid Glass needs iOS 26 / macOS 26. On anything older — or on visionOS, where
/// the API is unavailable — the glass cases fall back to `.solid`, so this is safe
/// to set unconditionally.
public enum PathMenuSurface: String, CaseIterable, Hashable, Sendable, Identifiable {
    /// Opaque tinted disc. The original AwesomeMenu look.
    case solid
    /// Liquid Glass, regular: frosted, with a clear sense of material.
    case regularGlass
    /// Liquid Glass, clear: far more of the backdrop shows through. Meant for use
    /// over rich content, and worth pairing with a tint for legibility.
    case clearGlass
    /// One merged surface: petals bond to each other and to the trigger as they
    /// pass, and part again as they travel out.
    ///
    /// Unlike the others this is not a per-petal material — there is one
    /// silhouette drawn beneath all of them — so it is the one surface that
    /// needs the menu to know where every petal is at once.
    case gooey

    public var id: String { rawValue }

    /// Deliberately false for `.gooey`. This gates `GlassEffectContainer`, and
    /// goo is not glass; merging it as though it were would put two materials in
    /// one view, which is how a system starts disagreeing with itself.
    public var isGlass: Bool { self == .regularGlass || self == .clearGlass }

    public var title: String {
        switch self {
        case .solid: "Solid"
        case .regularGlass: "Regular glass"
        case .clearGlass: "Clear glass"
        case .gooey: "Gooey"
        }
    }
}

/// What happens to the petals when one of them is chosen.
public enum PathMenuSelectionEffect: Hashable, Sendable {
    /// The original: the chosen petal blows up and fades, the rest shrink away.
    case blowUp
    /// Everything simply closes along the normal return path.
    case close
    /// Nothing; the menu stays as it is and only the callback fires.
    case none
}

// MARK: - Style

/// Every knob the menu exposes. A plain value type, so configurations are cheap to
/// build, compare, and store.
public struct PathMenuStyle: Equatable, Sendable {

    // Geometry ---------------------------------------------------------------

    /// Radius of the pull-back waypoint. 110 in the original.
    public var nearRadius: CGFloat = 110
    /// Radius the petals come to rest at. 120 in the original.
    public var endRadius: CGFloat = 120
    /// Radius of the initial overshoot. 140 in the original.
    public var farRadius: CGFloat = 140
    /// Total arc the petals are distributed over. A full turn spreads them evenly
    /// around the trigger; smaller sweeps fan them out.
    public var wholeAngle: Angle = .degrees(360)
    /// Rotates the whole fan. Zero puts the first petal straight up.
    public var rotationOffset: Angle = .zero
    /// Diameter of a petal. Drives the default visuals and the drag hit radius.
    public var petalDiameter: CGFloat = 46
    /// Diameter of the trigger's default visuals.
    public var triggerDiameter: CGFloat = 56

    // Timing -----------------------------------------------------------------

    /// Duration of a single petal's travel. 0.5 in the original.
    public var duration: Double = 0.5
    /// Delay added per petal, so they leave and return in sequence. 0.036 in the
    /// original, where it was the interval of an `NSTimer`.
    public var stagger: Double = 0.036
    /// Duration of the trigger's rotation. 0.3 in the original.
    public var triggerDuration: Double = 0.3

    // Rotation ---------------------------------------------------------------

    /// How far a petal is spun as it leaves. π in the original.
    public var expandRotation: Angle = .degrees(180)
    /// How far a petal is spun as it returns. 2π in the original.
    public var closeRotation: Angle = .degrees(360)
    /// Where the trigger rotates to while open. −π/4 in the original.
    public var triggerRotation: Angle = .degrees(-45)
    /// Whether the trigger rotates at all.
    public var rotatesTrigger: Bool = true
    /// Whether petals spin as they travel.
    public var rotatesPetals: Bool = true

    /// Which motion curve drives the travel.
    public var motion: PathMenuMotion = .classic

    // Surface ----------------------------------------------------------------

    /// Background treatment of the built-in visuals.
    public var surface: PathMenuSurface = .solid
    /// Tint each petal's glass with that item's colour. Off leaves the glass
    /// neutral, so it takes its colour entirely from whatever is behind it.
    public var glassTinted: Bool = true
    /// How strongly the item's colour tints its glass, as the tint's own opacity.
    public var glassTintStrength: Double = 0.55
    /// Let the glass respond to touch and pointer with its own highlight. Off by
    /// default: it adds a responsive layer per petal for an effect that is barely
    /// visible on a 46pt disc.
    public var glassInteractive: Bool = false
    /// Merge glass petals into one another (and into the trigger) when they come
    /// within this distance, via `GlassEffectContainer`. Zero leaves each element its
    /// own separate piece of glass.
    ///
    /// Off by default. Merging is the most expensive part of the glass surface —
    /// the union of every nearby glass shape is recomputed as the petals travel —
    /// so it is opt-in rather than something every menu pays for.
    public var glassBlendSpacing: CGFloat = 0

    /// How the gooey surface merges. Ignored by every other surface.
    public var goo: GlitchGooStyle = .standard
    /// Whether petals bond to the trigger as well as to one another. Off leaves
    /// the trigger a separate disc that the petals flow out from rather than out
    /// of.
    public var bondsTrigger: Bool = true

    // Behaviour --------------------------------------------------------------

    /// What choosing a petal looks like.
    public var selectionEffect: PathMenuSelectionEffect = .blowUp
    /// Whether the menu closes itself once a petal is chosen.
    public var closesOnSelect: Bool = true
    /// Press the trigger and drag straight onto a petal to choose it in one gesture.
    public var dragToSelect: Bool = true
    /// How generous drag targeting is, as a multiple of the petal's radius. The
    /// original accepted a touch anywhere in twice the item's bounds.
    public var dragTolerance: CGFloat = 1.4
    /// Highlight a petal when the pointer rests on it. The affordance a Mac (or
    /// iPad-with-pointer) user expects; harmless on touch-only devices, where no
    /// hover events are delivered.
    public var highlightsOnHover: Bool = true
    /// Impact feedback on expand and collapse, selection feedback on choose.
    public var hapticsEnabled: Bool = true
    /// A dimmed backdrop behind the expanded menu that dismisses it when tapped.
    public var dimsBackground: Bool = false
    /// Colour of that backdrop.
    public var dimColor: Color = .black.opacity(0.35)
    /// How far the backdrop extends. The component is only as large as its trigger,
    /// so the scrim cannot inherit the screen's bounds and is sized explicitly.
    public var scrimExtent: CGFloat = 2400

    public init() {}
}

// MARK: - Presets

extension PathMenuStyle {

    /// The original AwesomeMenu, constant for constant.
    public static let classic = PathMenuStyle()

    /// The original geometry with spring travel instead of the authored polyline.
    public static var springy: PathMenuStyle {
        var style = PathMenuStyle()
        style.motion = .smoothSpring
        return style
    }

    /// A quarter arc that fans up and to the left, for a button pinned to the
    /// bottom-trailing corner.
    public static var quarterCircleBottomTrailing: PathMenuStyle {
        var style = PathMenuStyle()
        style.wholeAngle = .degrees(90)
        style.rotationOffset = .degrees(-90)
        style.nearRadius = 105
        style.endRadius = 115
        style.farRadius = 132
        return style
    }

    /// A quarter arc that fans up and to the right, for a bottom-leading button.
    public static var quarterCircleBottomLeading: PathMenuStyle {
        var style = PathMenuStyle()
        style.wholeAngle = .degrees(90)
        style.rotationOffset = .zero
        style.nearRadius = 105
        style.endRadius = 115
        style.farRadius = 132
        return style
    }

    /// A half circle opening downwards, for a trigger near the top of the screen.
    public static var halfArcDown: PathMenuStyle {
        var style = PathMenuStyle()
        style.wholeAngle = .degrees(180)
        style.rotationOffset = .degrees(90)
        return style
    }

    /// A half circle opening upwards, for a trigger sitting near the bottom edge —
    /// the most common placement for a floating action button.
    public static var halfArcUp: PathMenuStyle {
        var style = PathMenuStyle()
        style.wholeAngle = .degrees(180)
        style.rotationOffset = .degrees(-90)
        return style
    }

    /// The classic geometry rendered in Liquid Glass, with the petals merging into
    /// one another as they pass close to the trigger.
    public static var liquidGlass: PathMenuStyle {
        var style = PathMenuStyle()
        style.surface = .regularGlass
        style.motion = .smoothSpring
        return style
    }

    /// Small and quick, for a toolbar or an inline control.
    public static var compact: PathMenuStyle {
        var style = PathMenuStyle()
        style.nearRadius = 66
        style.endRadius = 72
        style.farRadius = 84
        style.petalDiameter = 36
        style.triggerDiameter = 40
        style.duration = 0.34
        style.stagger = 0.028
        style.motion = .smoothSpring
        return style
    }
}

// MARK: - Environment

extension EnvironmentValues {
    /// Style used by any `PathMenu` that was not given one explicitly.
    @Entry public var pathMenuStyle: PathMenuStyle = .classic
}

extension View {
    /// Sets the style for every `PathMenu` in this subtree.
    public func pathMenuStyle(_ style: PathMenuStyle) -> some View {
        environment(\.pathMenuStyle, style)
    }
}

// MARK: - Phases handed to the caller's view builders

/// State of the trigger, handed to the trigger view builder.
public struct PathMenuTriggerPhase: Equatable, Sendable {
    /// Whether the menu is open or opening.
    public var isExpanded: Bool
    /// `1` while open, `0` while closed. Changes with the trigger's own animation,
    /// so it is useful for driving tints or scales alongside the rotation.
    public var progress: Double
    /// The rotation the menu applies to the trigger. Exposed for callers that set
    /// `rotatesTrigger` to `false` and want to do something else with it.
    public var rotation: Angle
}

/// State of a single petal, handed to the item view builder.
public struct PathMenuItemPhase: Equatable, Sendable {
    /// Position of this petal in the menu.
    public var index: Int
    /// The drag gesture is currently over this petal.
    public var isHighlighted: Bool
    /// This petal was the one chosen, and is playing its selection effect.
    public var isSelected: Bool
    /// The menu is open or opening.
    public var isExpanded: Bool
}
