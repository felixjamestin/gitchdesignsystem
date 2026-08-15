#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// The merge, drawn from a signed distance field.
//
// The reference this is borrowed from blurs its shapes and thresholds the
// result, then spends three more passes recovering edges the blur destroyed:
// erode-and-subtract for an inner highlight, offset-and-subtract for its twin,
// dilate for a shadow. All three are bands at a known distance from the
// silhouette, so with the distance itself in hand they are exact and nearly
// free — and the bridge between two shapes stops being a side effect of the
// blur radius and becomes a parameter of its own.

/// Signed distance to a rounded rectangle. Negative inside.
static float sdRoundedBox(float2 p, float2 halfSize, float r) {
    float2 q = abs(p) - halfSize + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

/// Transcribed from `glitchSmoothMin` in GlitchGooMath.swift, which is where it
/// is tested.
static float smoothMin(float a, float b, float k) {
    if (k <= 0.0) return min(a, b);
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

struct GooDistances {
    float body;
    float shadow;
    float lift;
};

static float2 warpedPosition(
    float2 p,
    float wobble,
    float wobbleSpeed,
    float phase
) {
    if (wobble <= 0.0) return p;

    return p + wobble * float2(
        sin(p.y * 0.06 * wobbleSpeed + phase * 6.283),
        cos(p.x * 0.06 * wobbleSpeed + phase * 6.283)
    );
}

/// Distances for the body and its two optional lighting samples.
///
/// All three values share one loop and one load of each shape. The previous
/// version ran the complete shape loop three times per pixel.
static GooDistances gooDistances(
    float2 position,
    device const float *shapes,
    int count,
    float blend,
    float shadowOffsetY,
    float rimOffsetY,
    float wobble,
    float wobbleSpeed,
    float phase,
    bool needsShadow,
    bool needsLift
) {
    float2 bodyPosition = warpedPosition(position, wobble, wobbleSpeed, phase);
    float2 shadowPosition = needsShadow
        ? warpedPosition(position - float2(0.0, shadowOffsetY), wobble, wobbleSpeed, phase)
        : bodyPosition;
    float2 liftPosition = needsLift
        ? warpedPosition(position - float2(0.0, rimOffsetY), wobble, wobbleSpeed, phase)
        : bodyPosition;

    // `count` is the length of the array in floats, not in shapes — SwiftUI
    // supplies it for the buffer it was handed, and knows nothing of how the
    // buffer is grouped. Looping to it directly reads five times past the end,
    // where the zeros it finds draw a phantom shape at the origin.
    int shapeCount = count / 5;

    // A quadratic smooth minimum pulls the surface in by at most k/4, so two
    // shapes bond only once the gap between them is under k/2. Doubling here
    // makes `blend` mean the thing anyone setting it expects — the widest gap
    // that still bridges — rather than twice that.
    float k = blend * 2.0;

    GooDistances distances = { 1e6, 1e6, 1e6 };
    for (int i = 0; i < shapeCount; ++i) {
        int base = i * 5;
        float2 center = float2(shapes[base], shapes[base + 1]);
        float2 halfSize = float2(shapes[base + 2], shapes[base + 3]);
        float radius = shapes[base + 4];
        distances.body = smoothMin(
            distances.body,
            sdRoundedBox(bodyPosition - center, halfSize, radius),
            k
        );
        if (needsShadow) {
            distances.shadow = smoothMin(
                distances.shadow,
                sdRoundedBox(shadowPosition - center, halfSize, radius),
                k
            );
        }
        if (needsLift) {
            distances.lift = smoothMin(
                distances.lift,
                sdRoundedBox(liftPosition - center, halfSize, radius),
                k
            );
        }
    }
    return distances;
}

/// Coverage of the silhouette at a distance, antialiased over `softness`.
static float gooCoverage(float d, float softness) {
    return smoothstep(softness, -softness, d);
}

[[ stitchable ]] half4 glitchGoo(
    float2 position,
    half4 color,
    device const float *shapes,
    int count,
    float blend,
    float edgeSoftness,
    float rimWidth,
    float rimOpacity,
    float rimOffsetY,
    float rimSecondaryOpacity,
    float shadowRadius,
    float shadowOpacity,
    float shadowOffsetY,
    float wobble,
    float wobbleSpeed,
    float phase,
    half4 fill
) {
    float softness = max(edgeSoftness, 0.01);

    bool needsShadow = shadowOpacity > 0.0001 && shadowRadius > 0.0001;
    bool needsLift = rimSecondaryOpacity > 0.0001 && abs(rimOffsetY) > 0.0001;
    GooDistances distances = gooDistances(
        position,
        shapes,
        count,
        blend,
        shadowOffsetY,
        rimOffsetY,
        wobble,
        wobbleSpeed,
        phase,
        needsShadow,
        needsLift
    );

    float d = distances.body;
    float body = gooCoverage(d, softness);

    // Shadow: the band just outside the silhouette, sampled from a copy shifted
    // the other way so the light appears to come from above.
    float shadow = needsShadow
        ? (1.0 - smoothstep(0.0, max(shadowRadius, 0.01), distances.shadow)) * shadowOpacity
        : 0.0;
    // Only outside the body — a shadow showing through the shape it belongs to
    // would darken the fill rather than seat it.
    shadow *= (1.0 - body);

    // Inner rim: brightest right at the edge, fading inwards over `rimWidth`.
    float rim = saturate((d + max(rimWidth, 0.01)) / max(rimWidth, 0.01)) * body * rimOpacity;

    // Its offset twin. The reference subtracts a downward-shifted copy of the
    // silhouette from itself, which leaves the upper edge — a lit top rather
    // than a uniform outline.
    float lit = needsLift
        ? body * (1.0 - gooCoverage(distances.lift, softness)) * rimSecondaryOpacity
        : 0.0;

    // Composited bottom-up, premultiplied throughout: shadow, then the fill over
    // it, then the two highlights.
    //
    // The incoming `color` is deliberately ignored. This kernel generates rather
    // than filters — the view it runs on exists only to give it pixels to run
    // over, and multiplying by a source alpha that is not the shape's would
    // erase everything it just drew.
    // `fill` arrives premultiplied, as everything in this pipeline is, so it is
    // composited as it stands. Premultiplying it again here is the reason an
    // earlier version drew a blob you could barely see.
    half bodyCoverage = half(body);
    half surfaceAlpha = fill.a * bodyCoverage;
    half3 surfaceRGB = fill.rgb * bodyCoverage;

    // Brighten the surface inside its existing alpha. Adding an opaque white
    // band changed the silhouette and produced chalky seams on translucent
    // controls.
    half highlight = half(saturate(rim + lit));
    surfaceRGB = mix(surfaceRGB, half3(surfaceAlpha), highlight);

    half shadowAlpha = half(shadow);
    half outputAlpha = surfaceAlpha + shadowAlpha * (1.0h - surfaceAlpha);
    return half4(surfaceRGB, outputAlpha);
}

/// The blur path's second half: threshold what has already been blurred.
///
/// This is the reference's `feColorMatrix` on the alpha channel, and the reason
/// that renderer cannot separate edge hardness from bridge width — both fall out
/// of these two numbers.
[[ stitchable ]] half4 glitchGooThreshold(
    float2 position,
    half4 color,
    float contrast,
    float bias
) {
    // The incoming colour is premultiplied; recover the straight colour before
    // reshaping alpha, or the fill darkens as the threshold bites.
    half alpha = color.a;
    half3 straight = alpha > 0.0h ? color.rgb / alpha : half3(0.0h);

    half shaped = clamp(alpha * half(contrast) - half(bias), 0.0h, 1.0h);
    return half4(straight * shaped, shaped);
}
