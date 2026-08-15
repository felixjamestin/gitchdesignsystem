#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// Probe kernel. Replaced by the real one in Task 4; it exists first so the
// packaging question can be answered before anything depends on the answer.
[[ stitchable ]] half4 glitchGooProbe(float2 position, half4 color) {
    return color;
}
