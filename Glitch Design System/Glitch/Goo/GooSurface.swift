import SwiftUI

/// Where the goo shader lives. The same `Goo.metal` is compiled by SwiftPM
/// into this module's own metallib and by Xcode into the app's default
/// library — the file is shared through the synchronized group — so the
/// lookup depends on how this code was built.
enum GooShader {
    static var library: ShaderLibrary {
        #if SWIFT_PACKAGE
        ShaderLibrary.bundle(.module)
        #else
        ShaderLibrary.default
        #endif
    }

    /// Packs the blobs into the flat quad layout the shader walks.
    static func goo(blobs: [GooBlob], smoothing: CGFloat, edge: CGFloat, fill: Color) -> Shader {
        var quads: [Float] = []
        quads.reserveCapacity(blobs.count * 4)
        for blob in blobs {
            quads.append(Float(blob.center.x))
            quads.append(Float(blob.center.y))
            quads.append(Float(blob.halfLength))
            quads.append(Float(blob.radius))
        }
        return library.glitchGoo(
            .float(smoothing),
            .float(edge),
            .color(fill),
            .floatArray(quads)
        )
    }
}

/// A rectangle of liquid: draws its blobs as one merged silhouette.
///
/// Blob coordinates are in the view's own space, so the caller decides the
/// canvas and the shader never needs to know about bounds. The content is an
/// opaque rectangle rather than clear because a fully transparent layer may
/// be culled before the shader runs; every visible pixel is the shader's.
struct GooSurface: View {
    var blobs: [GooBlob]
    var smoothing: CGFloat
    var edge: CGFloat = 0
    var fill: Color

    var body: some View {
        Rectangle()
            .fill(Color.white)
            .colorEffect(GooShader.goo(blobs: blobs, smoothing: smoothing, edge: edge, fill: fill))
            .allowsHitTesting(false)
    }
}

#Preview("Goo surface") {
    // Two circles close enough to neck, and a stadium, on one canvas.
    GooSurface(
        blobs: [
            GooBlob(center: CGPoint(x: 120, y: 70), radius: 34),
            GooBlob(center: CGPoint(x: 190, y: 70), radius: 22),
            GooBlob(center: CGPoint(x: 160, y: 160), halfLength: 70, radius: 24),
        ],
        smoothing: 20,
        fill: .orange
    )
    .frame(width: 320, height: 230)
    .background(Color.black)
}
