// swift-tools-version: 6.0
import PackageDescription

// The design system is a library first and a demo app second.
//
// `Sources` deliberately points into the app's own folder rather than the
// conventional `Sources/Glitch`: the Xcode target uses a file-system
// synchronized group, so the demo app compiles exactly the files this package
// vends. One copy, no mirroring, and no way for the two to drift.
//
// The demo (`App/`, `Demo/`) stays out of the library — nobody importing a
// control set wants a playground canvas with it.
let package = Package(
    name: "Glitch",
    platforms: [
        // Liquid Glass, `Group(subviews:)` and `@Entry` all need this floor.
        .macOS("26.0"),
        .iOS("26.0"),
    ],
    products: [
        .library(name: "Glitch", targets: ["Glitch"]),
    ],
    targets: [
        .target(
            name: "Glitch",
            path: "Glitch Design System/Glitch",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "GlitchTests",
            dependencies: ["Glitch"],
            path: "Tests/GlitchMathTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
