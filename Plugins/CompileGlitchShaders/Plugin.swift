import Foundation
import PackagePlugin

/// Compiles the package's `.metal` sources into a `default.metallib`.
///
/// SwiftPM does not handle Metal itself: left undeclared a `.metal` file is
/// reported as unhandled and dropped, and declared as a resource its *source* is
/// copied verbatim, which leaves `ShaderLibrary.bundle(.module)` with nothing to
/// resolve. So the compile is done here, and the result lands in the target's
/// resources where that call expects to find it.
///
/// The demo app needs none of this — its synchronized group hands the `.metal`
/// straight to Xcode, which has always known what to do with one.
@main
struct CompileGlitchShaders: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let target = target as? SourceModuleTarget else { return [] }

        let sources = target.sourceFiles
            .map(\.url)
            .filter { $0.pathExtension == "metal" }
        guard !sources.isEmpty else { return [] }

        let output = context.pluginWorkDirectoryURL.appending(path: "default.metallib")

        // No `-sdk` flag: `xcrun` already honours `SDKROOT`, which Xcode sets
        // per destination, so an iOS build compiles against the iOS SDK and a
        // plain `swift build` falls back to macOS. Passing one explicitly would
        // pin every platform to whichever we named.
        //
        // Verified on macOS only — this machine has no iOS platform installed.

        return [
            .buildCommand(
                displayName: "Compiling Glitch shaders",
                executable: URL(fileURLWithPath: "/usr/bin/xcrun"),
                arguments: ["metal", "-o", output.path(percentEncoded: false)]
                    + sources.map { $0.path(percentEncoded: false) },
                inputFiles: sources,
                outputFiles: [output]
            )
        ]
    }
}
