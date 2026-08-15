import SwiftUI

/// Where the goo kernels are found, and whether they are there at all.
///
/// The package and the demo app compile the same `.metal` file by two different
/// routes — a build-tool plugin for one, Xcode's synchronized group for the
/// other — so the compiled library lands in a different bundle in each. This is
/// the only place that knows that.
///
/// SwiftPM has no native handling for Metal: an undeclared `.metal` file is
/// dropped with a warning, and one declared as a resource has its *source*
/// copied uncompiled. Hence `Plugins/CompileGlitchShaders`, whose output is
/// copied into the resource bundle — which exists only because the manifest
/// also declares the shader source as a resource.
enum GlitchShaderLibrary {

    /// The library the goo kernels are drawn from.
    static var library: ShaderLibrary {
        #if SWIFT_PACKAGE
        ShaderLibrary.bundle(.module)
        #else
        ShaderLibrary.default
        #endif
    }

    /// Whether the compiled library is present.
    ///
    /// Resolved once, and deliberately not an error when false: a missing
    /// library demotes the renderer to one that needs no shader, exactly as
    /// switching delight off does. `ShaderLibrary` resolves function names
    /// lazily and only fails at draw time, so this asks the bundle rather than
    /// the library.
    static let isAvailable: Bool = {
        #if SWIFT_PACKAGE
        Bundle.module.url(forResource: "default", withExtension: "metallib") != nil
        #else
        Bundle.main.url(forResource: "default", withExtension: "metallib") != nil
        #endif
    }()
}
