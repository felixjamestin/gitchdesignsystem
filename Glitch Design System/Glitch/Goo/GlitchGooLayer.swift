import SwiftUI

/// Draws a set of shapes merged into one another.
///
/// Decoration only. Nothing here is hit-testable and nothing here is the
/// control — the real field, the real button, the real petals draw on top of it
/// and keep their own gestures, their own focus and their own accessibility.
/// That separation is what the reference achieves with `feComposite atop`, and
/// it is what lets the merge be switched off entirely without the control
/// losing anything it can do.
struct GlitchGooLayer: View {

    @Environment(\.glitchDelight) private var delight

    /// Centres relative to the layer's own centre, which is where every control
    /// here naturally has its anchor.
    let shapes: [GlitchGooShape]
    let style: GlitchGooStyle
    let fill: Color
    /// How large a canvas to draw on. The controls size this themselves: a
    /// radial menu's footprint is only its trigger, so the room the petals need
    /// cannot be inherited and has to be stated.
    let size: CGSize
    /// Drives the wobble, when there is one. The control's own progress rather
    /// than a clock, so the surface ripples while it moves and is still at rest.
    var phase: Double = 0

    var body: some View {
        Group {
            switch resolvedRenderer {
            case .sdf: distanceField
            case .blurThreshold: shaded { blurred }
            case .plain: shaded { plain }
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Which technique actually runs.
    ///
    /// Delight comes first: the merge is an embellishment, and that switch
    /// governs embellishment. Then availability — a distance field asked for
    /// without a compiled shader to draw it falls to the blur rather than
    /// drawing nothing.
    private var resolvedRenderer: GlitchGooRenderer {
        guard delight else { return .plain }
        if style.renderer == .sdf, !GlitchShaderLibrary.isAvailable { return .blurThreshold }
        return style.renderer
    }

    /// The drop shadow, for the two renderers that cannot derive one.
    ///
    /// The distance field gets its shadow — and its rim highlight — out of the
    /// distance it already has, which is the whole economy of the approach. The
    /// other two would each need the reference's extra dilate and erode passes
    /// to match, so they take the platform's shadow instead and go without the
    /// rim. A fallback that looks a little flatter is a fair trade; one that
    /// changes the silhouette would not be.
    @ViewBuilder
    private func shaded(@ViewBuilder content: () -> some View) -> some View {
        content()
            .shadow(
                color: .black.opacity(style.shadowOpacity),
                radius: style.shadowRadius,
                y: style.shadowOffsetY
            )
    }

    /// Shape centres arrive relative to the layer's centre; the kernel works in
    /// the layer's own coordinates. Shifting here means nothing that builds a
    /// shape needs to know where the layer sits.
    private var centred: [GlitchGooShape] {
        let delta = CGSize(width: size.width / 2, height: size.height / 2)
        return shapes.map { $0.offset(by: delta) }
    }

    // MARK: - Distance field

    private var distanceField: some View {
        // Opaque, not clear: a `colorEffect` only runs where the view it is
        // attached to actually puts pixels, so the rectangle is the canvas the
        // kernel draws over rather than an image it filters. The kernel ignores
        // the colour it is handed.
        Rectangle()
            .fill(.white)
            .colorEffect(
                GlitchShaderLibrary.library.glitchGoo(
                    .floatArray(GlitchGooPacking.pack(centred)),
                    .float(Float(style.blend)),
                    .float(Float(style.edgeSoftness)),
                    .float(Float(style.rimWidth)),
                    .float(Float(style.rimOpacity)),
                    .float(Float(style.rimOffsetY)),
                    .float(Float(style.rimSecondaryOpacity)),
                    .float(Float(style.shadowRadius)),
                    .float(Float(style.shadowOpacity)),
                    .float(Float(style.shadowOffsetY)),
                    .float(Float(style.wobble)),
                    .float(Float(style.wobbleSpeed)),
                    .float(Float(phase)),
                    .color(fill)
                )
            )
    }

    // MARK: - Blur and threshold

    /// The reference's own method, ported.
    ///
    /// Costs an offscreen composite and a full Gaussian every frame — the exact
    /// cost the rest of this system goes out of its way to avoid — so it is
    /// never the default. It earns its place by running without a compiled
    /// shader, and by being the only path that could merge arbitrary views.
    private var blurred: some View {
        // The silhouette is built opaque and the colour applied through it,
        // rather than the shapes being drawn in the fill colour directly.
        //
        // Thresholding works on alpha, so a translucent fill — which is what
        // every resting surface in this system is — has already fallen below
        // the threshold before the comparison happens, and the whole shape
        // vanishes. Masking keeps the maths on a solid silhouette and lets the
        // fill keep its own transparency.
        Rectangle()
            .fill(fill)
            .mask {
                ZStack {
                    ForEach(Array(centred.enumerated()), id: \.offset) { _, shape in
                        RoundedRectangle(cornerRadius: shape.cornerRadius, style: .continuous)
                            .fill(.white)
                            .frame(width: shape.size.width, height: shape.size.height)
                            .position(shape.center)
                    }
                }
                .compositingGroup()
                // A Gaussian whose sigma is a third of the blend width bridges
                // shapes at about the distance the field does, so the one
                // slider means roughly the same thing in either renderer.
                .blur(radius: style.blend / 3)
                .colorEffect(
                    GlitchShaderLibrary.library.glitchGooThreshold(
                        .float(Float(style.crispness)),
                        // Half the contrast puts the cut at the blur's
                        // half-alpha contour — where two shapes meet.
                        .float(Float(style.crispness / 2 - 0.5))
                    )
                )
            }
    }

    // MARK: - Plain

    /// The floor: every shape drawn, none of them merged. What delight switching
    /// off resolves to, and proof that the merge was only ever decoration.
    private var plain: some View {
        ZStack {
            ForEach(Array(centred.enumerated()), id: \.offset) { _, shape in
                RoundedRectangle(cornerRadius: shape.cornerRadius, style: .continuous)
                    .fill(fill)
                    .frame(width: shape.size.width, height: shape.size.height)
                    .position(shape.center)
            }
        }
    }
}

#Preview("Renderers") {
    @Previewable @State var separation = 34.0

    let shapes = { (gap: Double) in
        [
            GlitchGooShape.circle(center: CGPoint(x: -gap / 2, y: 0), diameter: 54),
            GlitchGooShape.circle(center: CGPoint(x: gap / 2, y: 0), diameter: 42),
        ]
    }

    return VStack(spacing: 18) {
        ForEach(GlitchGooRenderer.allCases) { renderer in
            var style = GlitchGooStyle.standard
            let _ = style.renderer = renderer

            VStack(spacing: 4) {
                Text(renderer.title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                GlitchGooLayer(
                    shapes: shapes(separation),
                    style: style,
                    fill: GlitchPalette.dark.trackActive,
                    size: CGSize(width: 240, height: 80)
                )
            }
        }
        GlitchSlider("Separation", value: $separation, in: 0...140)
            .frame(width: 240)
    }
    .padding(24)
    .background(GlitchPalette.dark.background)
    .glitchTheme()
    .preferredColorScheme(.dark)
}
