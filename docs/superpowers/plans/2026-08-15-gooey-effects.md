# Gooey Effects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two liquid-merge effects to the design system — a text field that sheds a submit button, and a gooey surface for the existing radial menu — on a shared rendering layer with two interchangeable renderers and a parameter lab for tuning both.

**Architecture:** One shared goo layer under `Glitch/Goo/` renders a list of analytic shapes through either a Metal SDF `colorEffect` (default, one fragment pass, no offscreen) or a blur-and-threshold port of the reference's SVG filter (fallback, and the path that survives without a compiled shader). Both controls feed that layer shapes; the crisp content draws on top. The radial menu's gooey surface hoists petal animation to one container-level master clock so the blob and the icons cannot drift.

**Tech Stack:** SwiftUI, Metal (`[[stitchable]]` shaders via `ShaderLibrary`), Swift 5 language mode, Swift Testing via SPM, Xcode file-system-synchronized project group.

**Spec:** `docs/superpowers/specs/2026-08-15-gooey-effects-design.md`

## Global Constraints

- Deployment floor is **iOS 26.0 / macOS 26.0** as declared in `Package.swift`. Do not raise it.
- Swift language mode stays **5.0**. Do not migrate to Swift 6 concurrency.
- Public types are prefixed `Glitch`. `PathMenu*` types are the one existing exception and stay as they are.
- **No ad-hoc animations.** Every animation comes from a `GlitchMotion` token.
- **No `#if os(...)` inside control bodies.** Platform branching stays in `Glitch/Motion/` and `GlitchDensity.platformDefault`.
- Files under `Glitch Design System/` are auto-compiled by the synchronized group. **Never edit `project.pbxproj`.**
- Pure-maths files must import only `Foundation`/`CoreGraphics` — never SwiftUI — and must be `public`, because the SPM test target compiles them.
- Every custom-drawn control declares accessibility traits, a value, and where relevant an adjustable action.
- `.glitchDelight(false)` may remove embellishment but **never** changes which values a control can reach or what it can do.
- Build verification: `xcodebuild -scheme "Glitch Design System" -destination 'platform=macOS' build`
- Test verification: `swift test`
- Both must pass. The package and the app compile the same files by different routes, which is exactly what Task 1 turns on.

---

## File Structure

```
Plugins/
  CompileGlitchShaders/Plugin.swift        # NEW  build-tool plugin: .metal → default.metallib

Glitch Design System/Glitch/
  Goo/
    GlitchGooMath.swift                    # NEW  smin + shape packing. Pure, no SwiftUI, public
    GlitchGooShape.swift                   # NEW  GooShape value type
    GlitchGooStyle.swift                   # NEW  parameters, presets, environment
    GlitchShaderLibrary.swift              # NEW  library resolution + availability
    GlitchGooLayer.swift                   # NEW  the view; three backends
    GlitchGoo.metal                        # NEW  the kernels
  Controls/
    GlitchGooField.swift                   # NEW  the field control
    GlitchPathMenu.swift                   # MOD  expose gooey surface
    PathMenu/
      PathMenuStyle.swift                  # MOD  .gooey case + goo style
      PathMenuGeometry.swift               # MOD  master-clock progress derivation
      PathMenu.swift                       # MOD  goo layer + master clock
      PathMenuPetal.swift                  # MOD  externally-driven mode

Glitch Design System/Demo/
  GooLabView.swift                         # NEW  fourth tab
  GalleryView.swift                        # MOD  Gooey group + surface picker
Glitch Design System/App/
  GlitchDesignSystemApp.swift              # MOD  register tab

Tests/GlitchMathTests/
  GooMathTests.swift                       # NEW  smin, packing, master clock

Package.swift                              # MOD  plugin target + resources
README.md                                  # MOD  document the new surface area
```

---

### Task 1: Shader packaging spike

The spec's one unresolved question. Everything else assumes an answer, so this lands first. **Decision gate:** if step 4 fails after one honest attempt, take the documented fallback and move on — do not spend the plan's budget here.

**Files:**
- Create: `Plugins/CompileGlitchShaders/Plugin.swift`
- Create: `Glitch Design System/Glitch/Goo/GlitchGoo.metal` (minimal kernel; grown in Task 4)
- Create: `Glitch Design System/Glitch/Goo/GlitchShaderLibrary.swift`
- Modify: `Package.swift`

**Interfaces:**
- Produces: `GlitchShaderLibrary.library: ShaderLibrary`, `GlitchShaderLibrary.isAvailable: Bool`

- [ ] **Step 1: Write the minimal kernel**

`GlitchGoo.metal`:

```metal
#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 glitchGooProbe(float2 position, half4 color) {
    return color;
}
```

- [ ] **Step 2: Add the build-tool plugin**

`Plugins/CompileGlitchShaders/Plugin.swift`:

```swift
import PackagePlugin
import Foundation

@main
struct CompileGlitchShaders: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let target = target as? SourceModuleTarget else { return [] }
        let metalFiles = target.sourceFiles
            .filter { $0.url.pathExtension == "metal" }
            .map(\.url)
        guard !metalFiles.isEmpty else { return [] }

        let output = context.pluginWorkDirectoryURL.appending(path: "default.metallib")
        let xcrun = URL(fileURLWithPath: "/usr/bin/xcrun")

        return [
            .buildCommand(
                displayName: "Compiling Glitch shaders",
                executable: xcrun,
                arguments: ["metal", "-o", output.path()] + metalFiles.map { $0.path() },
                inputFiles: metalFiles,
                outputFiles: [output]
            )
        ]
    }
}
```

- [ ] **Step 3: Wire it into the manifest**

In `Package.swift`, add to `targets:`:

```swift
.plugin(name: "CompileGlitchShaders", capability: .buildTool(), path: "Plugins/CompileGlitchShaders"),
```

and on the `GlitchDesignSystem` target add `plugins: ["CompileGlitchShaders"]`.

- [ ] **Step 4: Verify a metallib is produced**

Run: `swift build 2>&1 | tail -5 && find .build -name "default.metallib"`
Expected: a `default.metallib` path is printed.

**If this fails** (plugin sandbox blocks `xcrun`, or no metallib appears): stop, record the failure in a comment at the top of `GlitchShaderLibrary.swift`, remove the plugin target from `Package.swift`, delete `Plugins/`, and continue with the interim from the spec — the app target compiles the `.metal` through its synchronized group and package consumers demote to the blur renderer. Task 5 makes that demotion graceful, so nothing downstream breaks.

- [ ] **Step 5: Write the library resolver**

`GlitchShaderLibrary.swift`:

```swift
import SwiftUI

/// Where the goo kernels are found, and whether they are there at all.
///
/// The package and the demo app compile the same `.metal` file by different
/// routes — a build-tool plugin for one, the synchronized group for the other —
/// so which bundle holds the compiled library differs between them. This is the
/// only place that knows that.
enum GlitchShaderLibrary {
    static var library: ShaderLibrary {
        #if SWIFT_PACKAGE
        ShaderLibrary.bundle(.module)
        #else
        ShaderLibrary.default
        #endif
    }

    /// Resolved once. A missing library is not an error — it demotes the
    /// renderer, exactly as switching delight off does.
    static let isAvailable: Bool = probe()

    private static func probe() -> Bool { /* see Step 6 */ false }
}
```

- [ ] **Step 6: Make the probe honest**

`ShaderLibrary` resolves function names lazily and traps only at draw time, so the probe cannot ask it directly. Check for the compiled library on disk instead:

```swift
private static func probe() -> Bool {
    #if SWIFT_PACKAGE
    Bundle.module.url(forResource: "default", withExtension: "metallib") != nil
    #else
    Bundle.main.url(forResource: "default", withExtension: "metallib") != nil
        || Bundle.main.url(forResource: "default", withExtension: "metallib", subdirectory: "Frameworks") != nil
    #endif
}
```

- [ ] **Step 7: Both builds pass**

Run: `swift build && xcodebuild -scheme "Glitch Design System" -destination 'platform=macOS' build 2>&1 | tail -3`
Expected: both succeed.

- [ ] **Step 8: Commit**

```bash
git add Package.swift Plugins "Glitch Design System/Glitch/Goo"
git commit -m "Teach the package to compile a shader"
```

---

### Task 2: Goo maths

Pure, SwiftUI-free, public, unit-tested — the rule every `Glitch/Math`-class file follows, because the SPM test target compiles them.

**Files:**
- Create: `Glitch Design System/Glitch/Goo/GlitchGooMath.swift`
- Create: `Glitch Design System/Glitch/Goo/GlitchGooShape.swift`
- Create: `Tests/GlitchMathTests/GooMathTests.swift`

**Interfaces:**
- Produces:
  - `public func glitchSmoothMin(_ a: Double, _ b: Double, k: Double) -> Double`
  - `public struct GlitchGooShape: Equatable, Sendable` with `center: CGPoint`, `size: CGSize`, `cornerRadius: CGFloat`; statics `circle(center:diameter:)`, `capsule(center:size:)`
  - `public enum GlitchGooPacking { static let stride = 5; static let capacity = 16; static func pack(_ shapes: [GlitchGooShape]) -> [Float] }`

- [ ] **Step 1: Write the failing tests**

`Tests/GlitchMathTests/GooMathTests.swift`:

```swift
import Testing
import CoreGraphics
@testable import GlitchDesignSystem

@Suite("Goo maths")
struct GooMathTests {

    @Test("smooth min never exceeds the hard min")
    func neverExceedsMin() {
        for a in stride(from: -50.0, through: 50.0, by: 7.0) {
            for b in stride(from: -50.0, through: 50.0, by: 7.0) {
                #expect(glitchSmoothMin(a, b, k: 12) <= min(a, b) + 1e-9)
            }
        }
    }

    @Test("smooth min is commutative")
    func commutative() {
        #expect(abs(glitchSmoothMin(3, -8, k: 10) - glitchSmoothMin(-8, 3, k: 10)) < 1e-12)
    }

    @Test("smooth min collapses to hard min as k vanishes")
    func collapsesToMin() {
        #expect(abs(glitchSmoothMin(3, -8, k: 0) - (-8)) < 1e-12)
        #expect(abs(glitchSmoothMin(3, -8, k: 1e-9) - (-8)) < 1e-6)
    }

    @Test("packing round-trips centre, size and radius")
    func packingRoundTrips() {
        let shapes = [
            GlitchGooShape.circle(center: CGPoint(x: 10, y: -4), diameter: 46),
            GlitchGooShape.capsule(center: CGPoint(x: 0, y: 0), size: CGSize(width: 200, height: 44)),
        ]
        let packed = GlitchGooPacking.pack(shapes)
        #expect(packed.count == shapes.count * GlitchGooPacking.stride)
        #expect(packed[0] == 10)
        #expect(packed[1] == -4)
        #expect(packed[2] == 23)   // half-width
        #expect(packed[3] == 23)   // half-height
        #expect(packed[4] == 23)   // corner radius — a circle is a fully rounded square
        #expect(packed[7] == 22)   // capsule half-height
    }

    @Test("packing refuses to exceed the kernel's capacity")
    func packingClamps() {
        let many = Array(repeating: GlitchGooShape.circle(center: .zero, diameter: 10), count: 40)
        #expect(GlitchGooPacking.pack(many).count == GlitchGooPacking.capacity * GlitchGooPacking.stride)
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `swift test --filter GooMathTests`
Expected: FAIL — `glitchSmoothMin` and `GlitchGooShape` do not exist.

- [ ] **Step 3: Implement**

`GlitchGooMath.swift` — the polynomial smooth minimum, the same one the kernel uses, so the maths is verified on the CPU and merely transcribed to the GPU:

```swift
import CoreGraphics
import Foundation

/// Polynomial smooth minimum. `k` is the width of the blend, in the same units
/// as the distances — so it reads directly as how thick the bridge between two
/// shapes is, independent of how soft their edges are.
///
/// At `k == 0` this is exactly `min`, which is what makes the parameter safe to
/// animate down to nothing.
public func glitchSmoothMin(_ a: Double, _ b: Double, k: Double) -> Double {
    guard k > 0 else { return min(a, b) }
    let h = max(k - abs(a - b), 0) / k
    return min(a, b) - h * h * k * 0.25
}
```

`GlitchGooShape.swift` — one shape kind covers both cases: a rounded rectangle whose corner radius equals its half-height is a capsule, and one whose half-width also matches is a circle.

```swift
import CoreGraphics

/// A shape the goo layer can merge. Rounded rectangles only — a capsule is one
/// whose corner radius matches its half-height, and a circle is a capsule whose
/// sides have closed up. One primitive means one branch in the kernel.
public struct GlitchGooShape: Equatable, Sendable {
    public var center: CGPoint
    public var size: CGSize
    public var cornerRadius: CGFloat

    public init(center: CGPoint, size: CGSize, cornerRadius: CGFloat) { … }

    public static func circle(center: CGPoint, diameter: CGFloat) -> Self { … }
    public static func capsule(center: CGPoint, size: CGSize) -> Self { … }
}

public enum GlitchGooPacking {
    /// centre x, centre y, half-width, half-height, corner radius.
    public static let stride = 5
    /// Mirrors the kernel's declared maximum. Packing clamps rather than
    /// overruns: a menu with more petals than this loses the merge on the
    /// extras, which is a visual compromise rather than a crash.
    public static let capacity = 16

    public static func pack(_ shapes: [GlitchGooShape]) -> [Float] { … }
}
```

- [ ] **Step 4: Run to verify they pass**

Run: `swift test --filter GooMathTests`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add "Glitch Design System/Glitch/Goo" Tests/GlitchMathTests/GooMathTests.swift
git commit -m "Work out what merging two shapes means"
```

---

### Task 3: Parameters

**Files:**
- Create: `Glitch Design System/Glitch/Goo/GlitchGooStyle.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `public struct GlitchGooStyle: Equatable, Sendable`; `public enum GlitchGooRenderer: String, CaseIterable, Hashable, Sendable, Identifiable { case sdf, blurThreshold, plain }` with `var title: String`; presets `.standard`, `.tight`, `.loose`; `@Entry var glitchGooStyle`; `func glitchGooStyle(_:) -> some View`.

- [ ] **Step 1: Write the style**

Every parameter from the spec's table, each with the doc comment that says what it does and why it is separate from its neighbour. Follow `PathMenuStyle`'s shape exactly: `public var` with a default, grouped under `// MARK:` headings, presets in an extension, environment at the bottom.

```swift
public struct GlitchGooStyle: Equatable, Sendable {
    // Merge -------------------------------------------------------------
    public var renderer: GlitchGooRenderer = .sdf
    /// Width of the blend between two shapes — how thick the bridge is. Read in
    /// points, and independent of `crispness`, which is the whole reason for
    /// preferring a distance field to a blur.
    public var blend: CGFloat = 18
    /// How hard the merged edge lands. Under `.blurThreshold` this is the alpha
    /// multiplier the reference calls contrast.
    public var crispness: Double = 18
    /// Antialias width in points. `.sdf` only — the blur path's edge softness is
    /// a consequence of `crispness` and cannot be set separately.
    public var edgeSoftness: CGFloat = 1

    // Lighting ----------------------------------------------------------
    public var rimWidth: CGFloat = 1
    public var rimOpacity: Double = 0.04
    public var rimOffsetY: CGFloat = 1
    public var rimSecondaryOpacity: Double = 0.03
    public var shadowRadius: CGFloat = 1
    public var shadowOpacity: Double = 0.06
    public var shadowOffsetY: CGFloat = 0

    // Surface -----------------------------------------------------------
    /// `nil` takes the theme's `trackActive`, so goo matches every other
    /// resting surface without being told to.
    public var fill: Color?

    // Liquid ------------------------------------------------------------
    /// Amplitude of a sinusoidal displacement of the distance field. Zero by
    /// default: it costs a `sin` per shape per pixel, and it is the parameter
    /// most likely to grate on the hundredth use.
    public var wobble: CGFloat = 0
    public var wobbleSpeed: Double = 1

    public init() {}
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build`
Expected: success.

- [ ] **Step 3: Commit**

```bash
git add "Glitch Design System/Glitch/Goo/GlitchGooStyle.swift"
git commit -m "Give the goo its knobs"
```

---

### Task 4: The SDF kernel and the layer

**Files:**
- Modify: `Glitch Design System/Glitch/Goo/GlitchGoo.metal`
- Create: `Glitch Design System/Glitch/Goo/GlitchGooLayer.swift`

**Interfaces:**
- Consumes: `GlitchGooShape`, `GlitchGooPacking`, `GlitchGooStyle`, `GlitchShaderLibrary`.
- Produces: `struct GlitchGooLayer: View` initialised as `GlitchGooLayer(shapes: [GlitchGooShape], style: GlitchGooStyle, fill: Color, size: CGSize)`.

- [ ] **Step 1: Write the kernel**

Replace `glitchGooProbe` with the real one. `.floatArray` arrives as a pointer plus an `int` count; keep the signature in that order or SwiftUI will not bind it.

```metal
static float sdRoundedBox(float2 p, float2 halfSize, float r) {
    float2 q = abs(p) - halfSize + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

static float smoothMin(float a, float b, float k) {
    if (k <= 0.0) return min(a, b);
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

[[ stitchable ]] half4 glitchGoo(
    float2 position, half4 color,
    device const float *shapes, int count,
    float blend, float edgeSoftness,
    float rimWidth, float rimOpacity, float rimOffsetY, float rimSecondaryOpacity,
    float shadowRadius, float shadowOpacity, float shadowOffsetY,
    half4 fill
) { … }
```

Shade fill, rim and shadow from the one distance: fill is `smoothstep(edgeSoftness, -edgeSoftness, d)`; the rim is the band `d ∈ [-rimWidth, 0]`, evaluated a second time against a distance sampled at `position - float2(0, rimOffsetY)` for the offset twin; the shadow is the band `d ∈ [0, shadowRadius]` sampled at `position - float2(0, shadowOffsetY)`. Composite shadow under fill, rim over.

- [ ] **Step 2: Write the layer's SDF backend**

```swift
struct GlitchGooLayer: View {
    let shapes: [GlitchGooShape]
    let style: GlitchGooStyle
    let fill: Color
    let size: CGSize

    var body: some View { … }

    private var sdfLayer: some View {
        Rectangle()
            .fill(.clear)
            .frame(width: size.width, height: size.height)
            .colorEffect(
                GlitchShaderLibrary.library.glitchGoo(
                    .floatArray(GlitchGooPacking.pack(centred(shapes))),
                    .float(Float(min(shapes.count, GlitchGooPacking.capacity))),
                    …
                )
            )
    }
}
```

Shape centres arrive relative to the control's anchor; the kernel works in the layer's own coordinates, so `centred(_:)` shifts them by `size / 2`. Do this on the Swift side — the kernel should not need to know where the layer sits.

- [ ] **Step 3: Verify it draws**

Add a `#Preview` showing two circles at varying separations. Run the macOS app or the preview.
Expected: two discs that bond into one as they approach, with a visible neck.

**If the preview canvas shows nothing**, that is the known Metal-in-previews limitation from the spec — check in the running app before treating it as a defect.

- [ ] **Step 4: Commit**

```bash
git add "Glitch Design System/Glitch/Goo"
git commit -m "Draw the merge from a distance field"
```

---

### Task 5: The other two backends

The blur path is not a toy — it is what package consumers fall back to if Task 1 took its fallback, and `.plain` is what the delight switch resolves to.

**Files:**
- Modify: `Glitch Design System/Glitch/Goo/GlitchGoo.metal`
- Modify: `Glitch Design System/Glitch/Goo/GlitchGooLayer.swift`

- [ ] **Step 1: Add the threshold kernel**

```metal
[[ stitchable ]] half4 glitchGooThreshold(float2 position, half4 color, float contrast, float bias) {
    half a = color.a * half(contrast) - half(bias);
    a = clamp(a, 0.0h, 1.0h);
    return half4(color.rgb * a, a);
}
```

- [ ] **Step 2: Add the blur backend**

Draw the shapes as ordinary filled `RoundedRectangle`s in a `ZStack`, then `.compositingGroup()`, `.blur(radius: style.blend / 3)`, `.colorEffect(threshold)`. The divisor converts a blend width in points into the Gaussian sigma that produces a bridge of about that thickness, which is what keeps the `blend` slider meaning the same thing in both renderers.

- [ ] **Step 3: Add the plain backend and the resolution rule**

```swift
private var resolvedRenderer: GlitchGooRenderer {
    guard delight else { return .plain }
    if style.renderer == .sdf, !GlitchShaderLibrary.isAvailable { return .blurThreshold }
    return style.renderer
}
```

- [ ] **Step 4: Verify all three**

Extend the `#Preview` to show the same two circles under each renderer side by side.
Expected: `.sdf` and `.blurThreshold` both bridge; `.plain` shows two separate discs.

- [ ] **Step 5: Commit**

```bash
git add "Glitch Design System/Glitch/Goo"
git commit -m "Give the goo somewhere to fall back to"
```

---

### Task 6: `GlitchGooField`

**Files:**
- Create: `Glitch Design System/Glitch/Controls/GlitchGooField.swift`

**Interfaces:**
- Consumes: `GlitchGooLayer`, `GlitchGooStyle`, `GlitchGooShape`.
- Produces: `public struct GlitchGooField: View`, initialised as `GlitchGooField(text: Binding<String>, placeholder: String = "", trigger: GlitchGooFieldTrigger = .focus, onSubmit: @escaping () -> Void)`; `public enum GlitchGooFieldTrigger { case focus, nonEmpty, always }`.

- [ ] **Step 1: Build the anatomy**

A capsule holding the wrapped `TextField`, and a circular submit button. Both are real, hit-testable views; the goo layer draws *behind* them and is purely decorative, which is what keeps the button a button and the field a field. Wrap the platform `TextField` exactly as `GlitchTextField` does — `.textFieldStyle(.plain)`, `.focusEffectDisabled()`, `GlitchType.value(theme)` — for the reason its doc comment already gives.

- [ ] **Step 2: Drive the separation**

One animatable `Double` — `detachment`, 0 to 1 — drives the button's offset, the capsule's contraction, and the shapes handed to the goo layer. Animate it with the `motion.glide` token. Never declare an animation locally.

- [ ] **Step 3: Accessibility and behaviour**

The button gets `.accessibilityLabel("Submit")` and fires `onSubmit`. `onSubmit` also fires on return in the field. Under `.plain` the button simply appears without a bridge — **the field submits identically in every renderer and at every delight setting.**

- [ ] **Step 4: Verify**

Run: `xcodebuild -scheme "Glitch Design System" -destination 'platform=macOS' build`, then run the app.
Expected: focusing the field sheds the button with a visible neck that breaks; blurring re-absorbs it.

- [ ] **Step 5: Commit**

```bash
git add "Glitch Design System/Glitch/Controls/GlitchGooField.swift"
git commit -m "Let a field shed its submit button"
```

---

### Task 7: The master clock

The derivation that keeps blob and icon together. Pure and tested first, because a defect here desyncs them silently and no screenshot catches it.

**Files:**
- Modify: `Glitch Design System/Glitch/Controls/PathMenu/PathMenuGeometry.swift`
- Modify: `Tests/GlitchMathTests/GooMathTests.swift`

**Interfaces:**
- Produces: `func petalProgress(master: Double, index: Int, count: Int, duration: Double, stagger: Double, reversed: Bool) -> Double` on a new `struct PathMenuClock: Equatable, Sendable`.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite("Path menu master clock")
struct PathMenuClockTests {
    let clock = PathMenuClock()

    @Test("the first petal starts immediately and the last starts latest")
    func staggerOrder() {
        #expect(clock.petalProgress(master: 0, index: 0, count: 3, duration: 0.5, stagger: 0.1, reversed: false) == 0)
        #expect(clock.petalProgress(master: 0.5, index: 0, count: 3, duration: 0.5, stagger: 0.1, reversed: false) > 0)
        #expect(clock.petalProgress(master: 0.1, index: 2, count: 3, duration: 0.5, stagger: 0.1, reversed: false) == 0)
    }

    @Test("every petal has arrived when the master clock completes")
    func allArrive() {
        for index in 0 ..< 5 {
            #expect(clock.petalProgress(master: 1, index: index, count: 5, duration: 0.5, stagger: 0.036, reversed: false) == 1)
        }
    }

    @Test("closing reverses the order")
    func reversedOrder() {
        let first = clock.petalProgress(master: 0.1, index: 0, count: 3, duration: 0.5, stagger: 0.1, reversed: true)
        let last = clock.petalProgress(master: 0.1, index: 2, count: 3, duration: 0.5, stagger: 0.1, reversed: true)
        #expect(last > first)
    }

    @Test("a single petal ignores stagger entirely")
    func singlePetal() {
        #expect(clock.petalProgress(master: 0.5, index: 0, count: 1, duration: 0.5, stagger: 0.2, reversed: false) == 0.5)
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `swift test --filter PathMenuClockTests`
Expected: FAIL — `PathMenuClock` does not exist.

- [ ] **Step 3: Implement**

`total = duration + stagger * (count - 1)`; a petal's delay is `stagger * index`, or `stagger * (count - 1 - index)` reversed — matching the delays `PetalTimeline.make` already computes, because the gooey path must land on identical geometry to the path it replaces. Then `clamp((master * total - delay) / duration, 0, 1)`.

- [ ] **Step 4: Run to verify they pass**

Run: `swift test --filter PathMenuClockTests`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add "Glitch Design System/Glitch/Controls/PathMenu/PathMenuGeometry.swift" Tests/GlitchMathTests/GooMathTests.swift
git commit -m "Work out where every petal is at once"
```

---

### Task 8: The gooey surface

**Files:**
- Modify: `Glitch Design System/Glitch/Controls/PathMenu/PathMenuStyle.swift`
- Modify: `Glitch Design System/Glitch/Controls/PathMenu/PathMenuPetal.swift`
- Modify: `Glitch Design System/Glitch/Controls/PathMenu/PathMenu.swift`

- [ ] **Step 1: Extend the style**

Add `case gooey` to `PathMenuSurface` with `title` "Gooey", and `public var goo: GlitchGooStyle = GlitchGooStyle()` plus `public var bondsTrigger: Bool = true` to `PathMenuStyle`. `isGlass` must stay false for `.gooey` — it gates `GlassEffectContainer`, and goo is not glass.

- [ ] **Step 2: Give the petal an externally-driven mode**

Add `let externalProgress: Double?` to `PathMenuPetal`. When non-nil, skip the `KeyframeAnimator` entirely and apply `timeline.path.point(at: externalProgress!)` directly. When nil — every existing caller — behave exactly as now.

- [ ] **Step 3: Add the master clock and the goo layer to `PathMenu`**

On `.gooey` only: one `KeyframeAnimator` over a single `Double` at the container level, spanning `totalDuration`, its trigger the existing `runtime` phase. Its value feeds `PathMenuClock` for each petal's `externalProgress`, and the same positions build the `[GlitchGooShape]` for a `GlitchGooLayer` placed in a `.background` beneath the petals — the same slot the petals themselves use, so it contributes nothing to layout.

Size the layer explicitly: `2 * (endRadius + petalDiameter / 2 + shadowRadius + blend)` square. The menu's footprint is only its trigger, which is why `scrimExtent` is an explicit number too.

- [ ] **Step 4: Verify no regression**

Run: `swift test && xcodebuild -scheme "Glitch Design System" -destination 'platform=macOS' build`, then open the Gallery and exercise the existing radial menu.
Expected: solid and glass surfaces behave exactly as before — same timing, same stagger, same drag-to-select.

- [ ] **Step 5: Commit**

```bash
git add "Glitch Design System/Glitch/Controls/PathMenu"
git commit -m "Let the petals bond as they travel"
```

---

### Task 9: Wire it into the themed menu

**Files:**
- Modify: `Glitch Design System/Glitch/Controls/GlitchPathMenu.swift`

- [ ] **Step 1: Accept a surface**

Add `surface: PathMenuSurface = .solid` to the initialiser and set it on `resolvedStyle`. Feed `style.goo.fill` from `theme.palette.trackActive` when the caller left it nil.

- [ ] **Step 2: Fold goo under delight**

In `resolvedStyle`, goo joins `selectionEffect` and `rotatesPetals`: when delight is off, the surface falls back to `.solid`. The comment already there — "The blow-up is a flourish, and flourishes are what the delight switch governs" — covers this too.

- [ ] **Step 3: Verify**

Run the app, set the menu to gooey.
Expected: petals bond to one another and to the trigger while travelling; drag-to-select, sound and haptics unchanged.

- [ ] **Step 4: Commit**

```bash
git add "Glitch Design System/Glitch/Controls/GlitchPathMenu.swift"
git commit -m "Offer the gooey surface through the theme"
```

---

### Task 10: The lab

**Files:**
- Create: `Glitch Design System/Demo/GooLabView.swift`
- Modify: `Glitch Design System/App/GlitchDesignSystemApp.swift`

- [ ] **Step 1: Build the tab**

Both effects above a `GlitchPanel` of live controls, built from the system's own: `GlitchSegmented` for `renderer`, `GlitchSlider` for every numeric parameter with the ranges from `GlitchGooStyle`'s defaults, `GlitchToggle` for `bondsTrigger`, and `GlitchButton`s for the presets. State lives in `GooLabView`; both effects read the one `GlitchGooStyle`, so tuning moves them together.

- [ ] **Step 2: Register the tab**

Add `GlitchTabItem(id: 3, title: "Goo Lab", systemImage: "drop")` to `RootView.tabs` and a `case 3` to `screen`. `default:` currently returns `MotionLabView` — change it to `case 2` and make Goo Lab the new `default:`, or the tab will never be reachable.

- [ ] **Step 3: Verify**

Run the app, open Goo Lab, sweep every slider.
Expected: both effects respond live; switching renderer changes the look without changing behaviour.

- [ ] **Step 4: Commit**

```bash
git add "Glitch Design System/Demo/GooLabView.swift" "Glitch Design System/App/GlitchDesignSystemApp.swift"
git commit -m "Put the goo somewhere it can be played with"
```

---

### Task 11: The catalogue and the README

**Files:**
- Modify: `Glitch Design System/Demo/GalleryView.swift`
- Modify: `README.md`

- [ ] **Step 1: Add the Gooey group**

Following the existing `group(_:)` pattern: `GlitchGooField` in its ordinary, filled and disabled states, plus an `explain(_:)` line in the voice of the ones around it.

- [ ] **Step 2: Add the surface picker**

In the existing "Radial menu" group, a `GlitchSegmented` over `PathMenuSurface.allCases` bound to new `@State`, passed to `GlitchPathMenu`.

- [ ] **Step 3: Document it**

In `README.md`: `GlitchGooField` under "Text", the gooey surface under "Radial menu", and a `GlitchGooStyle` parameter table. Match the surrounding register — what it does and why it is the way it is, not a list of properties.

- [ ] **Step 4: Verify**

Run: `swift test && xcodebuild -scheme "Glitch Design System" -destination 'platform=macOS' build`, then walk every tab.
Expected: all green, nothing in the Gallery regressed.

- [ ] **Step 5: Commit**

```bash
git add "Glitch Design System/Demo/GalleryView.swift" README.md
git commit -m "Show the goo in the catalogue and write it down"
```

---

## Self-Review

**Spec coverage.** Rendering approach → Tasks 4, 5. Shader packaging → Task 1, with its fallback wired into Task 5's resolution rule. Shared layer's five files → Tasks 1–5. `GlitchGooField` → Task 6. Radial menu surface, master clock, petal mode → Tasks 7, 8, 9. Parameters → Task 3, exposed in Task 10. Demo (both homes) → Tasks 10, 11. Testing → Tasks 2, 7. Docs → Task 11. No gaps.

**Placeholders.** The `…` in Tasks 2, 3, 4 and 6 stand in for bodies whose algorithm is specified in prose immediately beside them and whose signatures are fixed in the Interfaces blocks — an implementer has everything needed to write them. No "TBD", no "handle edge cases", no test-free steps.

**Type consistency.** `GlitchGooShape`, `GlitchGooPacking.pack`, `glitchSmoothMin`, `GlitchGooStyle`, `GlitchGooRenderer`, `GlitchShaderLibrary.isAvailable`, `PathMenuClock.petalProgress`, `GlitchGooLayer(shapes:style:fill:size:)` are each defined once and referred to under the same name everywhere after. The kernel name `glitchGoo` matches the `ShaderLibrary.library.glitchGoo(...)` call site; `glitchGooThreshold` likewise.

**One ordering hazard, flagged in place:** Task 10 Step 2 — `RootView.screen` uses `default:` for the Motion Lab, so adding a fourth tab without restructuring the switch silently makes it unreachable.
