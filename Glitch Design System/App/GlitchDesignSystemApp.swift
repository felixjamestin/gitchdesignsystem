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
    /// Held here rather than inside the Motion Lab so the slowdown applies to
    /// every tab — you can slow the system down, then go watch the Playground.
    @State private var motionScale: Double = 1
    @State private var forceReduceMotion = false
    @State private var density: GlitchDensity = .platformDefault

    var body: some View {
        TabView {
            Tab("Playground", systemImage: "slider.horizontal.below.square.filled.and.square") {
                PlaygroundView()
            }
            Tab("Gallery", systemImage: "square.grid.2x2") {
                GalleryView(density: $density)
            }
            Tab("Motion Lab", systemImage: "waveform.path") {
                MotionLabView(
                    motionScale: $motionScale,
                    forceReduceMotion: $forceReduceMotion
                )
            }
        }
        .background(GlitchPalette.dark.background)
        .glitchTheme(density: density)
        .glitchMotion(scale: motionScale, reduceMotion: forceReduceMotion)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RootView()
}
