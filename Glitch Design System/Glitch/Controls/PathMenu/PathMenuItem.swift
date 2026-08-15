import SwiftUI

// MARK: - Model

/// A ready-made menu entry, for the common case where a petal is just a symbol.
///
/// The generic `PathMenu` accepts any `Identifiable` data with any view; this exists
/// so the simple case stays a one-liner.
public struct PathMenuItem: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var systemImage: String
    public var tint: Color

    public init(
        id: String? = nil,
        title: String,
        systemImage: String,
        tint: Color = .accentColor
    ) {
        self.id = id ?? title
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
    }
}

// MARK: - Default petal

/// Default visuals for a `PathMenuItem`: a tinted disc with a symbol.
public struct PathMenuPetalLabel: View {
    private let item: PathMenuItem
    private let phase: PathMenuItemPhase
    private let overrideStyle: PathMenuStyle?

    @Environment(\.pathMenuStyle) private var environmentStyle

    public init(item: PathMenuItem, phase: PathMenuItemPhase, style: PathMenuStyle? = nil) {
        self.item = item
        self.phase = phase
        self.overrideStyle = style
    }

    private var style: PathMenuStyle { overrideStyle ?? environmentStyle }

    public var body: some View {
        Group {
            #if os(visionOS)
            if style.surface == .gooey { gooForeground } else { solid }
            #else
            if style.surface == .gooey {
                gooForeground
            } else if #available(iOS 26.0, macOS 26.0, *), style.surface.isGlass {
                glass
            } else {
                solid
            }
            #endif
        }
        .scaleEffect(phase.isHighlighted ? 1.18 : 1)
        .animation(.snappy(duration: 0.18), value: phase.isHighlighted)
        .accessibilityLabel(Text(item.title))
    }

    private var symbol: some View {
        Image(systemName: item.systemImage)
            .font(.system(size: style.petalDiameter * 0.42, weight: .semibold))
    }

    private var solid: some View {
        Circle()
            .fill(item.tint.gradient)
            .overlay { symbol.foregroundStyle(.white) }
            .overlay { Circle().strokeBorder(.white.opacity(0.28), lineWidth: 0.8) }
            .frame(width: style.petalDiameter, height: style.petalDiameter)
            .shadow(color: .black.opacity(0.22), radius: 5, y: 2)
    }

    /// The goo renderer owns the complete surface. A second disc here would
    /// reveal every input circle as an internal ring.
    private var gooForeground: some View {
        symbol
            .foregroundStyle(.primary)
            .frame(width: style.petalDiameter, height: style.petalDiameter)
            .contentShape(Circle())
    }

    #if !os(visionOS)
    @available(iOS 26.0, macOS 26.0, *)
    private var glass: some View {
        // No drop shadow here: Liquid Glass casts and refracts on its own, and
        // stacking a manual shadow under it reads as a smudge.
        symbol
            .foregroundStyle(style.glassTinted ? AnyShapeStyle(.white) : AnyShapeStyle(item.tint))
            .frame(width: style.petalDiameter, height: style.petalDiameter)
            .glassEffect(petalGlass, in: .circle)
    }

    @available(iOS 26.0, macOS 26.0, *)
    private var petalGlass: Glass {
        let base: Glass = style.surface == .clearGlass ? .clear : .regular
        let tinted = style.glassTinted
            ? base.tint(item.tint.opacity(style.glassTintStrength))
            : base
        return tinted.interactive(style.glassInteractive)
    }
    #endif
}

// MARK: - Default trigger

/// Default visuals for the trigger: a disc with a symbol that the menu rotates.
public struct PathMenuTriggerLabel: View {
    private let systemImage: String
    private let phase: PathMenuTriggerPhase
    private let overrideStyle: PathMenuStyle?

    @Environment(\.pathMenuStyle) private var environmentStyle

    public init(
        systemImage: String = "plus",
        phase: PathMenuTriggerPhase,
        style: PathMenuStyle? = nil
    ) {
        self.systemImage = systemImage
        self.phase = phase
        self.overrideStyle = style
    }

    private var style: PathMenuStyle { overrideStyle ?? environmentStyle }

    public var body: some View {
        #if os(visionOS)
        if style.surface == .gooey { gooForeground } else { solid }
        #else
        if style.surface == .gooey {
            gooForeground
        } else if #available(iOS 26.0, macOS 26.0, *), style.surface.isGlass {
            glass
        } else {
            solid
        }
        #endif
    }

    private var symbol: some View {
        Image(systemName: systemImage)
            .font(.system(size: style.triggerDiameter * 0.4, weight: .bold))
    }

    private var solid: some View {
        Circle()
            .fill(Color.primary.opacity(phase.isExpanded ? 0.92 : 0.82).gradient)
            // `.background` resolves to the window's backing colour on every
            // platform, unlike `UIColor.systemBackground`.
            .overlay { symbol.foregroundStyle(.background) }
            .frame(width: style.triggerDiameter, height: style.triggerDiameter)
            .shadow(color: .black.opacity(0.28), radius: 8, y: 3)
    }

    private var gooForeground: some View {
        symbol
            .foregroundStyle(.primary)
            .frame(width: style.triggerDiameter, height: style.triggerDiameter)
            .contentShape(Circle())
    }

    #if !os(visionOS)
    @available(iOS 26.0, macOS 26.0, *)
    private var glass: some View {
        // The trigger stays untinted so the coloured petals read as the content and
        // it reads as the chrome they came out of.
        symbol
            .foregroundStyle(.primary)
            .frame(width: style.triggerDiameter, height: style.triggerDiameter)
            .glassEffect(
                (style.surface == .clearGlass ? Glass.clear : Glass.regular)
                    .interactive(style.glassInteractive),
                in: .circle
            )
    }
    #endif
}

// MARK: - Convenience

extension PathMenu
where
    Data == [PathMenuItem],
    ItemContent == PathMenuPetalLabel,
    TriggerContent == PathMenuTriggerLabel
{
    /// A menu of symbol petals with a default trigger — the shortest way to get the
    /// component on screen.
    public init(
        items: [PathMenuItem],
        style: PathMenuStyle? = nil,
        isExpanded: Binding<Bool>? = nil,
        systemImage: String = "plus",
        onSelect: @escaping (PathMenuItem) -> Void
    ) {
        self.init(
            items: items,
            style: style,
            isExpanded: isExpanded,
            onSelect: onSelect,
            trigger: { phase in
                PathMenuTriggerLabel(systemImage: systemImage, phase: phase, style: style)
            },
            item: { item, phase in
                PathMenuPetalLabel(item: item, phase: phase, style: style)
            }
        )
    }
}

// MARK: - Sample data

extension PathMenuItem {
    /// The five actions from the original Path menu, for previews and the demo.
    public static let samples: [PathMenuItem] = [
        PathMenuItem(title: "Photo", systemImage: "camera.fill", tint: .orange),
        PathMenuItem(title: "Person", systemImage: "person.fill", tint: .blue),
        PathMenuItem(title: "Place", systemImage: "mappin.and.ellipse", tint: .green),
        PathMenuItem(title: "Music", systemImage: "music.note", tint: .pink),
        PathMenuItem(title: "Thought", systemImage: "bubble.left.fill", tint: .purple),
        PathMenuItem(title: "Sleep", systemImage: "moon.fill", tint: .indigo)
    ]

    public static func samples(count: Int) -> [PathMenuItem] {
        guard count > samples.count else { return Array(samples.prefix(max(count, 1))) }
        return (0 ..< count).map { samples[$0 % samples.count] }
            .enumerated()
            .map { index, item in
                var copy = item
                copy.id = "\(item.id)-\(index)"
                return copy
            }
    }
}
