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

/// Distance to the merged silhouette of every shape.
static float gooDistance(
    float2 p,
    device const float *shapes,
    int count,
    float blend,
    float wobble,
    float wobbleSpeed,
    float phase
) {
    if (wobble > 0.0) {
        // Rippled while the shapes are moving and still when they are at rest,
        // because `phase` is the control's own progress rather than a clock.
        p += wobble * float2(
            sin(p.y * 0.06 * wobbleSpeed + phase * 6.283),
            cos(p.x * 0.06 * wobbleSpeed + phase * 6.283)
        );
    }

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

    float d = 1e6;
    for (int i = 0; i < shapeCount; ++i) {
        int base = i * 5;
        float2 center = float2(shapes[base], shapes[base + 1]);
        float2 halfSize = float2(shapes[base + 2], shapes[base + 3]);
        float radius = shapes[base + 4];
        d = smoothMin(d, sdRoundedBox(p - center, halfSize, radius), k);
    }
    return d;
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

    float d = gooDistance(position, shapes, count, blend, wobble, wobbleSpeed, phase);
    float body = gooCoverage(d, softness);

    // Shadow: the band just outside the silhouette, sampled from a copy shifted
    // the other way so the light appears to come from above.
    float dShadow = gooDistance(
        position - float2(0.0, shadowOffsetY),
        shapes, count, blend, wobble, wobbleSpeed, phase
    );
    float shadow = (1.0 - smoothstep(0.0, max(shadowRadius, 0.01), dShadow)) * shadowOpacity;
    // Only outside the body — a shadow showing through the shape it belongs to
    // would darken the fill rather than seat it.
    shadow *= (1.0 - body);

    // Inner rim: brightest right at the edge, fading inwards over `rimWidth`.
    float rim = saturate((d + max(rimWidth, 0.01)) / max(rimWidth, 0.01)) * body * rimOpacity;

    // Its offset twin. The reference subtracts a downward-shifted copy of the
    // silhouette from itself, which leaves the upper edge — a lit top rather
    // than a uniform outline.
    float dLift = gooDistance(
        position - float2(0.0, rimOffsetY),
        shapes, count, blend, wobble, wobbleSpeed, phase
    );
    float lit = body * (1.0 - gooCoverage(dLift, softness)) * rimSecondaryOpacity;

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
    half4 result = half4(0.0h, 0.0h, 0.0h, half(shadow));
    result = result * half(1.0 - body) + fill * half(body);
    result += half4(half3(1.0h), 1.0h) * half(rim + lit);

    return min(result, half4(1.0h));
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
