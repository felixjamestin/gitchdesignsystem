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
    @State private var scheme: ColorScheme = .dark
    @State private var density: GlitchDensity = .platformDefault

    /// Held here for the same reason: a slowdown set in the Motion Lab applies
    /// everywhere.
    @State private var motionScale: Double = 1
    @State private var forceReduceMotion = false

    var body: some View {
        TabView {
            Tab("Playground", systemImage: "slider.horizontal.below.square.filled.and.square") {
                PlaygroundView()
            }
            Tab("Gallery", systemImage: "square.grid.2x2") {
                GalleryView(style: $style, scheme: $scheme, density: $density)
            }
            Tab("Motion Lab", systemImage: "waveform.path") {
                MotionLabView(
                    motionScale: $motionScale,
                    forceReduceMotion: $forceReduceMotion
                )
            }
        }
        .glitchTheme(style, density: density)
        .glitchMotion(scale: motionScale, reduceMotion: forceReduceMotion)
        .preferredColorScheme(scheme)
    }
}

#Preview {
    RootView()
}
