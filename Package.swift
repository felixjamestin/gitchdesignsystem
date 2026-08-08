// swift-tools-version: 6.0
import PackageDescription

// This package exists solely to make the pure value/geometry math in
// `Glitch Design System/Glitch/Math` unit-testable from the command line with
// `swift test`. The app target compiles those same files via its
// file-system-synchronized group, so there is no duplication and no need to
// modify project.pbxproj.
//
// Files under Glitch/Math must therefore import only Foundation — never SwiftUI.

let package = Package(
    name: "GlitchMath",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "GlitchMath",
            path: "Glitch Design System/Glitch/Math",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "GlitchMathTests",
            dependencies: ["GlitchMath"],
            path: "Tests/GlitchMathTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
