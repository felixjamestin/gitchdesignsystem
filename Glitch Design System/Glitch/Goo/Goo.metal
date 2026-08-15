#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Mirrored in GooMath.stadiumDistance, where it is unit-tested.
static float stadium(float2 p, float2 c, float halfLength, float r) {
    float2 d = float2(p.x - clamp(p.x, c.x - halfLength, c.x + halfLength),
                      p.y - c.y);
    return length(d) - r;
}

// Mirrored in GooMath.smoothMin.
static float smin(float a, float b, float k) {
    if (k <= 0.0) { return min(a, b); }
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// The whole goo renderer: blobs arrive as quads of (centre x, centre y,
// half-length, radius) in view points, are folded together with a smooth
// minimum, and the joined distance becomes coverage through a smoothstep one
// derivative wide — an analytic edge, no blur pass anywhere.
[[ stitchable ]] half4 glitchGoo(float2 position,
                                 half4 color,
                                 float k,
                                 float edge,
                                 half4 fill,
                                 device const float *blobs,
                                 int count) {
    float d = 1e6;
    for (int i = 0; i + 3 < count; i += 4) {
        float2 c = float2(blobs[i], blobs[i + 1]);
        d = smin(d, stadium(position, c, blobs[i + 2], blobs[i + 3]), k);
    }
    float aa = max(fwidth(d), edge);
    float coverage = 1.0 - smoothstep(-aa, aa, d);
    return fill * half(coverage);
}
