import SwiftUI

@main
struct GlitchDesignSystemApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        #if os(macOS)
        .defaultSize(width: 1080, height: 760)
        #endif
    }
}

struct RootView: View {
    /// Appearance state lives here rather than in the Gallery so that changing
    /// it there also changes the Playground you go and look at next.
    @State private var style: GlitchThemeStyle = .glitch
    @State private var glass: GlitchGlassVariant = .regular
    @State private var scheme: ColorScheme = .dark
    @State private var density: GlitchDensity = .platformDefault
    @State private var delight = true

    /// Held here for the same reason: a slowdown set in the Motion Lab applies
    /// everywhere.
    @State private var motionScale: Double = 1
    @State private var forceReduceMotion = false

    @State private var selection = 0
    /// Which way the last move went, so the incoming screen arrives from the
    /// side it came from rather than always from the right.
    @State private var isForward = true

    private let tabs = [
        GlitchTabItem(id: 0, title: "Playground", systemImage: "slider.horizontal.3"),
        GlitchTabItem(id: 1, title: "Gallery", systemImage: "square.grid.2x2"),
        GlitchTabItem(id: 2, title: "Motion Lab", systemImage: "waveform.path"),
    ]

    var body: some View {
        ZStack {
            // A sibling of the content rather than a `.background`, so it sits
            // inside the theme this view installs and can read it.
            GlitchPageBackground()
                .ignoresSafeArea()

            VStack(spacing: 10) {
                GlitchTabBar(selection: tabSelection, items: tabs)
                    .frame(maxWidth: 520)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                content
            }
        }
        .glitchTheme(style, glass: glass, density: density)
        .glitchMotion(scale: motionScale, reduceMotion: forceReduceMotion)
        .glitchDelight(delight)
        .preferredColorScheme(scheme)
    }

    @ViewBuilder
    private var screen: some View {
        switch selection {
        case 0:
            PlaygroundView()
        case 1:
            GalleryView(
                style: $style,
                glass: $glass,
                scheme: $scheme,
                density: $density,
                delight: $delight
            )
        default:
            MotionLabView(
                motionScale: $motionScale,
                forceReduceMotion: $forceReduceMotion
            )
        }
    }

    private var content: some View {
        screen
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Changing the identity is what makes this a transition rather
            // than a redraw: the old screen leaves and a new one arrives.
            .id(selection)
            .transition(travelTransition)
            .clipped()
    }

    /// Out the way you came, in from the way you're going. A screen that
    /// always entered from the right would make going back feel like going
    /// forward again.
    private var travelTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: isForward ? .trailing : .leading)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.94)),
            removal: .move(edge: isForward ? .leading : .trailing)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.94))
        )
    }

    /// Records the direction, then lets the change through.
    ///
    /// The animation itself belongs to the tab bar, which wraps the write in
    /// `motion.travel` — so this transition and the indicator's slide are the
    /// same animation, and cannot drift apart.
    private var tabSelection: Binding<Int> {
        Binding(
            get: { selection },
            set: { next in
                guard next != selection else { return }
                isForward = next > selection
                selection = next
            }
        )
    }
}

#Preview {
    RootView()
}
