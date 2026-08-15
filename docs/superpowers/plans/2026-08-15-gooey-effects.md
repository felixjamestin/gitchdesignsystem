# Gooey Effects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Metal-SDF liquid "goo" renderer, a `GlitchGooField` text field whose submit button buds off on focus, a `.gooey` variant of `GlitchPathMenu`, and a Goo Lab demo tab with live parameters.

**Architecture:** One `colorEffect` Metal shader draws every goo silhouette: blobs are horizontal stadiums (capsule with `halfLength` 0 = circle) joined by a polynomial smooth-min, antialiased with `fwidth`. Swift mirrors of the SDF math live in `Glitch/Math/GooMath.swift` and are unit-tested. The field animates one detach progress through an `Animatable` view; the menu underlay runs a linear `KeyframeAnimator` clock and evaluates each petal's position with `Spring.value`, using the same spring and stagger the petals themselves use.

**Tech Stack:** SwiftUI (iOS 26 / macOS 26), SwiftUI `Shader`/`ShaderLibrary`, Metal (`[[stitchable]]`), Swift Testing (`@Suite`/`@Test`/`#expect`).

**Spec:** `docs/superpowers/specs/2026-08-15-gooey-effects-design.md`

## Global Constraints

- Platforms: `.macOS("26.0")`, `.iOS("26.0")` (already set in Package.swift; do not lower).
- Swift language mode: v5 (already set; keep new code warning-free under it).
- Library code lives under `Glitch Design System/Glitch/`; demo-only code under `Glitch Design System/Demo/`. The SPM target path is `Glitch Design System/Glitch` — anything inside it ships in the library.
- Tests live in `Tests/GlitchMathTests/`, plain `import GlitchDesignSystem` (no `@testable`) — so anything tests touch must be `public`.
- Build: `swift build` from the repo root. Tests: `swift test`. Both must pass at every commit.
- Comment style: sentence-case doc comments explaining *why*, matching existing files. No "MARK: added by" noise; follow the file's existing MARK pattern.
- Paths contain spaces — always quote them in shell commands.

---

### Task 1: Goo math and its tests

**Files:**
- Create: `Glitch Design System/Glitch/Math/GooMath.swift`
- Test: `Tests/GlitchMathTests/GooMathTests.swift`

**Interfaces:**
- Consumes: nothing (CoreGraphics only — no SwiftUI import in this file).
- Produces:
  - `public struct GooBlob: Equatable, Sendable { public var center: CGPoint; public var halfLength: CGFloat; public var radius: CGFloat; public init(center:halfLength:radius:) }` (halfLength defaults to 0)
  - `GooMath.stadiumDistance(_ point: CGPoint, center: CGPoint, halfLength: CGFloat, radius: CGFloat) -> CGFloat`
  - `GooMath.smoothMin(_ a: CGFloat, _ b: CGFloat, k: CGFloat) -> CGFloat`
  - `GooMath.fieldBlobs(in size: CGSize, buttonDiameter: CGFloat, detachDistance: CGFloat, progress: CGFloat) -> [GooBlob]`
  - `GooMath.menuDelay(index: Int, count: Int, stagger: Double, opening: Bool) -> Double`

- [ ] **Step 1: Write the failing tests**

Create `Tests/GlitchMathTests/GooMathTests.swift`:

```swift
import CoreGraphics
import Testing
import GlitchDesignSystem

@Suite("Goo math")
struct GooMathTests {

    // MARK: - Stadium distance

    @Test("a zero-length stadium is a circle")
    func circleDistance() {
        let c = CGPoint(x: 50, y: 50)
        #expect(GooMath.stadiumDistance(c, center: c, halfLength: 0, radius: 10) == -10)
        #expect(GooMath.stadiumDistance(CGPoint(x: 60, y: 50), center: c, halfLength: 0, radius: 10) == 0)
        #expect(GooMath.stadiumDistance(CGPoint(x: 75, y: 50), center: c, halfLength: 0, radius: 10) == 15)
    }

    @Test("distance above the stadium's straight section ignores the caps")
    func stadiumSide() {
        let d = GooMath.stadiumDistance(
            CGPoint(x: 50, y: 20),
            center: CGPoint(x: 50, y: 50), halfLength: 40, radius: 10
        )
        #expect(d == 20)   // 30 points above the axis, minus the radius
    }

    @Test("distance beyond the cap measures from the cap's centre")
    func stadiumCap() {
        // Cap centre sits at x = 90; the probe is 30 to its right.
        let d = GooMath.stadiumDistance(
            CGPoint(x: 120, y: 50),
            center: CGPoint(x: 50, y: 50), halfLength: 40, radius: 10
        )
        #expect(d == 20)
    }

    // MARK: - Smooth minimum

    @Test("smooth minimum is symmetric and never exceeds the plain minimum")
    func sminBasics() {
        #expect(GooMath.smoothMin(3, 7, k: 8) == GooMath.smoothMin(7, 3, k: 8))
        #expect(GooMath.smoothMin(3, 7, k: 8) <= 3)
    }

    @Test("zero smoothing is a hard union")
    func sminHard() {
        #expect(GooMath.smoothMin(3, 7, k: 0) == 3)
    }

    @Test("values further apart than k pass through untouched")
    func sminFar() {
        #expect(GooMath.smoothMin(3, 30, k: 8) == 3)
    }

    /// The property the whole effect rests on: between two nearby blobs the
    /// blended field dips below zero — a neck — where the hard union does not.
    @Test("smoothing forms a neck between nearby blobs")
    func sminNeck() {
        let a = CGPoint(x: 36, y: 50), b = CGPoint(x: 64, y: 50)
        let mid = CGPoint(x: 50, y: 50)
        let da = GooMath.stadiumDistance(mid, center: a, halfLength: 0, radius: 10)
        let db = GooMath.stadiumDistance(mid, center: b, halfLength: 0, radius: 10)
        #expect(min(da, db) > 0)                       // hard union: outside
        #expect(GooMath.smoothMin(da, db, k: 20) < 0)  // goo: inside the neck
    }

    // MARK: - Field blobs

    @Test("at progress 0 the button hides flush inside the capsule's end")
    func fieldMerged() {
        let blobs = GooMath.fieldBlobs(
            in: CGSize(width: 300, height: 40),
            buttonDiameter: 36, detachDistance: 16, progress: 0
        )
        let capsule = blobs[0], button = blobs[1]
        let capsuleRightEdge = capsule.center.x + capsule.halfLength + capsule.radius
        #expect(button.center.x + button.radius == capsuleRightEdge)
        // Fully contained: the union's silhouette is the capsule alone.
        #expect(button.radius <= capsule.radius)
    }

    @Test("at progress 1 the button has detached by the full gap and fills the footprint")
    func fieldDetached() {
        let width: CGFloat = 300
        let blobs = GooMath.fieldBlobs(
            in: CGSize(width: width, height: 40),
            buttonDiameter: 36, detachDistance: 16, progress: 1
        )
        let capsule = blobs[0], button = blobs[1]
        let capsuleRightEdge = capsule.center.x + capsule.halfLength + capsule.radius
        let gap = (button.center.x - button.radius) - capsuleRightEdge
        #expect(abs(gap - 16) < 0.001)
        #expect(abs((button.center.x + button.radius) - width) < 0.001)
    }

    @Test("the capsule never inverts when the control is narrow")
    func fieldNarrow() {
        let blobs = GooMath.fieldBlobs(
            in: CGSize(width: 60, height: 40),
            buttonDiameter: 36, detachDistance: 16, progress: 0.5
        )
        #expect(blobs[0].halfLength >= 0)
    }

    // MARK: - Menu delays

    @Test("petals leave first-to-last and return last-to-first")
    func menuDelays() {
        #expect(GooMath.menuDelay(index: 0, count: 5, stagger: 0.04, opening: true) == 0)
        #expect(GooMath.menuDelay(index: 2, count: 5, stagger: 0.04, opening: true) == 0.08)
        #expect(GooMath.menuDelay(index: 4, count: 5, stagger: 0.04, opening: false) == 0)
        #expect(GooMath.menuDelay(index: 0, count: 5, stagger: 0.04, opening: false) == 0.16)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd "/Users/felixjamestin/Documents/Glitch Design System" && swift test 2>&1 | tail -5`
Expected: compile FAILURE — `cannot find 'GooMath' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Glitch Design System/Glitch/Math/GooMath.swift`:

```swift
import CoreGraphics

/// One blob of goo: a horizontal stadium — a capsule whose straight section
/// runs along x — or, with `halfLength` zero, a circle.
public struct GooBlob: Equatable, Sendable {
    public var center: CGPoint
    public var halfLength: CGFloat
    public var radius: CGFloat

    public init(center: CGPoint, halfLength: CGFloat = 0, radius: CGFloat) {
        self.center = center
        self.halfLength = halfLength
        self.radius = radius
    }
}

/// The goo renderer's geometry, mirrored from `Goo.metal` so the field the
/// shader evaluates per pixel can be verified here without a GPU.
public enum GooMath {

    /// Signed distance from `point` to a stadium: negative inside, zero on the
    /// surface, positive outside.
    public static func stadiumDistance(
        _ point: CGPoint,
        center: CGPoint,
        halfLength: CGFloat,
        radius: CGFloat
    ) -> CGFloat {
        let nearestX = min(max(point.x, center.x - halfLength), center.x + halfLength)
        let dx = point.x - nearestX
        let dy = point.y - center.y
        return (dx * dx + dy * dy).squareRoot() - radius
    }

    /// Polynomial smooth minimum (Quilez). `k` is the blend range in points:
    /// distances within `k` of each other melt together, which is what pulls a
    /// neck of liquid between two nearby blobs. Zero is a hard union.
    public static func smoothMin(_ a: CGFloat, _ b: CGFloat, k: CGFloat) -> CGFloat {
        guard k > 0 else { return min(a, b) }
        let h = min(max(0.5 + 0.5 * (b - a) / k, 0), 1)
        return b + (a - b) * h - k * h * (1 - h)
    }

    /// Blob layout for `GlitchGooField`: a capsule filling the control minus
    /// the room the button needs, and a submit blob that starts flush inside
    /// the capsule's trailing end and detaches by `progress`.
    ///
    /// The footprint is constant: at rest the trailing margin is simply empty,
    /// so focusing never reflows the text or the neighbours.
    public static func fieldBlobs(
        in size: CGSize,
        buttonDiameter: CGFloat,
        detachDistance: CGFloat,
        progress: CGFloat
    ) -> [GooBlob] {
        let fieldRadius = size.height / 2
        let reach = detachDistance + buttonDiameter
        let capsuleWidth = max(size.width - reach, size.height)
        let capsule = GooBlob(
            center: CGPoint(x: capsuleWidth / 2, y: fieldRadius),
            halfLength: max(capsuleWidth / 2 - fieldRadius, 0),
            radius: fieldRadius
        )

        let buttonRadius = buttonDiameter / 2
        let mergedX = capsuleWidth - buttonRadius
        let detachedX = capsuleWidth + detachDistance + buttonRadius
        let button = GooBlob(
            center: CGPoint(x: mergedX + (detachedX - mergedX) * progress, y: fieldRadius),
            radius: buttonRadius
        )
        return [capsule, button]
    }

    /// Stagger delay for petal `index` of the gooey menu. Petals leave
    /// first-to-last and return last-to-first, as the original menu's timer
    /// counted — the same delays `PetalTimeline.make` computes.
    public static func menuDelay(
        index: Int,
        count: Int,
        stagger: Double,
        opening: Bool
    ) -> Double {
        opening ? Double(index) * stagger : Double(count - 1 - index) * stagger
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd "/Users/felixjamestin/Documents/Glitch Design System" && swift test 2>&1 | tail -5`
Expected: PASS — 3 old suites plus "Goo math", all green.

- [ ] **Step 5: Commit**

```bash
cd "/Users/felixjamestin/Documents/Glitch Design System" && git add "Glitch Design System/Glitch/Math/GooMath.swift" Tests/GlitchMathTests/GooMathTests.swift && git commit -m "Teach the system the geometry of goo"
```

---

### Task 2: The Metal shader and the goo surface

**Files:**
- Create: `Glitch Design System/Glitch/Goo/Goo.metal`
- Create: `Glitch Design System/Glitch/Goo/GooSurface.swift`

**Interfaces:**
- Consumes: `GooBlob` from Task 1.
- Produces (both `internal`):
  - `GooShader.goo(blobs: [GooBlob], smoothing: CGFloat, edge: CGFloat, fill: Color) -> Shader`
  - `struct GooSurface: View` with `init(blobs: [GooBlob], smoothing: CGFloat, edge: CGFloat = 0, fill: Color)` — renders the merged silhouette; blob coordinates are in the view's own space; hit-testing disabled.

- [ ] **Step 1: Write the shader**

Create `Glitch Design System/Glitch/Goo/Goo.metal`:

```metal
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
```

- [ ] **Step 2: Write the Swift side**

Create `Glitch Design System/Glitch/Goo/GooSurface.swift`:

```swift
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
```

- [ ] **Step 3: Build and confirm the metallib was produced**

Run:
```bash
cd "/Users/felixjamestin/Documents/Glitch Design System" && swift build 2>&1 | tail -3 && find .build -name "*.metallib" -path "*GlitchDesignSystem*" | head -3
```
Expected: `Build complete!` and at least one `default.metallib` inside the `GlitchDesignSystem_GlitchDesignSystem.bundle`. If the build succeeds but **no metallib appears**, SwiftPM did not pick up the shader — stop and report; do not silently continue (the demo would render opaque white rectangles).

- [ ] **Step 4: Run the tests (regression only)**

Run: `cd "/Users/felixjamestin/Documents/Glitch Design System" && swift test 2>&1 | tail -3`
Expected: PASS, same counts as Task 1.

- [ ] **Step 5: Commit**

```bash
cd "/Users/felixjamestin/Documents/Glitch Design System" && git add "Glitch Design System/Glitch/Goo" && git commit -m "Draw goo with a signed-distance shader"
```

---

### Task 3: GlitchGooField

**Files:**
- Create: `Glitch Design System/Glitch/Controls/GlitchGooField.swift`

**Interfaces:**
- Consumes: `GooMath.fieldBlobs(in:buttonDiameter:detachDistance:progress:)`, `GooSurface(blobs:smoothing:edge:fill:)`, theme environment (`\.glitchTheme`, `\.glitchMotion`, `\.isEnabled`), `GlitchSound.commit()`, `GlitchHaptics.impact()`, `GlitchType.value(theme)`.
- Produces:
  - `public struct GlitchGooFieldStyle: Sendable { public var goo: CGFloat = 14; public var detachDistance: CGFloat = 16; public var buttonDiameter: CGFloat = 0; public var edgeSoftness: CGFloat = 0; public var spring: Spring? = nil; public var tint: Color? = nil; public init() }`
  - `public struct GlitchGooField: View` with `init(text: Binding<String>, placeholder: String = "", style: GlitchGooFieldStyle = .init(), onSubmit: @escaping (String) -> Void = { _ in })`

- [ ] **Step 1: Write the control**

Create `Glitch Design System/Glitch/Controls/GlitchGooField.swift`:

```swift
import SwiftUI

/// Every knob the gooey field exposes. A plain value type, matching
/// `PathMenuStyle`'s approach: cheap to build, store, and hand to a demo.
public struct GlitchGooFieldStyle: Sendable {
    /// Blend range of the liquid union, in points. The gooeyness dial.
    public var goo: CGFloat = 14
    /// Surface-to-surface gap between the capsule and the detached button.
    public var detachDistance: CGFloat = 16
    /// Diameter of the submit button. Zero means "match the field height".
    public var buttonDiameter: CGFloat = 0
    /// Extra edge softness in points. Zero is a crisp antialiased edge.
    public var edgeSoftness: CGFloat = 0
    /// Spring for the bud-off travel. `nil` uses the theme's travel spring.
    public var spring: Spring? = nil
    /// Fill of the liquid. `nil` uses the palette's active track.
    public var tint: Color? = nil

    public init() {}
}

/// A capsule text field whose submit button buds off the trailing end when
/// focused, joined to the capsule by a stretching neck of liquid on the way.
///
/// Like `GlitchTextField`, the native `TextField` keeps its behaviour —
/// selection, input methods, the system keyboard — and loses only its
/// appearance. The liquid is drawn by the goo shader underneath; the layout
/// footprint is constant, with the trailing margin simply empty at rest, so
/// focusing never reflows the text or the neighbours.
public struct GlitchGooField: View {
    @Environment(\.glitchTheme) private var theme
    @Environment(\.glitchMotion) private var motion
    @Environment(\.isEnabled) private var isEnabled

    @Binding private var text: String
    private let placeholder: String
    private let style: GlitchGooFieldStyle
    private let onSubmit: (String) -> Void

    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String = "",
        style: GlitchGooFieldStyle = .init(),
        onSubmit: @escaping (String) -> Void = { _ in }
    ) {
        self._text = text
        self.placeholder = placeholder
        self.style = style
        self.onSubmit = onSubmit
    }

    public var body: some View {
        let metrics = theme.metrics
        let height = metrics.rowHeight
        let button = style.buttonDiameter > 0 ? style.buttonDiameter : height
        let reach = style.detachDistance + button
        let spring = style.spring ?? motion.travelSpring

        HStack(spacing: 0) {
            TextField(
                "",
                text: $text,
                prompt: Text(placeholder).foregroundStyle(theme.palette.labelSecondary)
            )
            .textFieldStyle(.plain)
            .focusEffectDisabled()
            .font(GlitchType.value(theme))
            .foregroundStyle(theme.palette.label)
            .focused($isFocused)
            .onSubmit(submit)
            .padding(.horizontal, metrics.hInset)

            // The room the button detaches into. Present at rest too, so the
            // capsule's width — and the text inside it — never moves.
            Color.clear
                .frame(width: reach)
                .overlay(alignment: .trailing) { submitButton(diameter: button) }
        }
        .frame(height: height)
        .background {
            GooFieldSurface(
                progress: isFocused ? 1 : 0,
                buttonDiameter: button,
                detachDistance: style.detachDistance,
                smoothing: style.goo,
                edge: style.edgeSoftness,
                fill: style.tint ?? theme.palette.trackActive
            )
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .opacity(isEnabled ? 1 : 0.4)
        .animation(.spring(spring), value: isFocused)
    }

    private func submitButton(diameter: CGFloat) -> some View {
        Button(action: submit) {
            Image(systemName: "arrow.right")
                .font(.system(size: theme.metrics.iconSize, weight: .semibold))
                .foregroundStyle(theme.palette.label)
                .frame(width: diameter, height: diameter)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        // Rides the same spring as the blob it sits on, so icon and liquid
        // arrive together; hidden and untouchable while merged.
        .opacity(isFocused ? 1 : 0)
        // Trailing-aligned resting centre is capsule end + detach + radius;
        // merged it must sit at capsule end − radius, hence this exact slide.
        .offset(x: isFocused ? 0 : -style.detachDistance - diameter)
        .allowsHitTesting(isFocused)
        .accessibilityLabel("Submit")
    }

    private func submit() {
        guard !text.isEmpty else { return }
        GlitchHaptics.impact()
        GlitchSound.commit()
        onSubmit(text)
    }
}

/// The liquid underlay. `Animatable` over the detach progress, so the spring
/// the field applies drives the shader's blob positions frame by frame —
/// per-frame work is a uniform update, never layout.
struct GooFieldSurface: View, Animatable {
    var progress: CGFloat
    var buttonDiameter: CGFloat
    var detachDistance: CGFloat
    var smoothing: CGFloat
    var edge: CGFloat
    var fill: Color

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        GeometryReader { proxy in
            GooSurface(
                blobs: GooMath.fieldBlobs(
                    in: proxy.size,
                    buttonDiameter: buttonDiameter,
                    detachDistance: detachDistance,
                    progress: progress
                ),
                smoothing: smoothing,
                edge: edge,
                fill: fill
            )
        }
    }
}

#Preview("Goo field") {
    @Previewable @State var email = ""

    VStack(spacing: 24) {
        GlitchGooField(text: $email, placeholder: "Enter your email") { _ in }
        GlitchGooField(text: $email, placeholder: "Locked").disabled(true)
    }
    .padding(32)
    .frame(width: 380)
    .background(GlitchPalette.dark.background)
    .glitchTheme()
    .glitchMotion()
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Build and run tests**

Run: `cd "/Users/felixjamestin/Documents/Glitch Design System" && swift build 2>&1 | tail -3 && swift test 2>&1 | tail -3`
Expected: `Build complete!`, all suites PASS.

- [ ] **Step 3: Commit**

```bash
cd "/Users/felixjamestin/Documents/Glitch Design System" && git add "Glitch Design System/Glitch/Controls/GlitchGooField.swift" && git commit -m "Let a text field bud off its submit button"
```

---

### Task 4: The gooey path menu variant

**Files:**
- Create: `Glitch Design System/Glitch/Goo/GooMenuUnderlay.swift`
- Modify: `Glitch Design System/Glitch/Controls/GlitchPathMenu.swift`

**Interfaces:**
- Consumes: `GooBlob`, `GooSurface`, `GooMath.menuDelay(index:count:stagger:opening:)`, `PathMenuGeometry` (internal, same module), `PathMenuStyle`, `Spring.value(fromValue:toValue:initialVelocity:time:)`.
- Produces:
  - `public enum GlitchPathMenuVariant: Hashable, Sendable { case standard, gooey }`
  - `public struct GlitchGooMenuStyle: Sendable { public var goo: CGFloat = 18; public var edgeSoftness: CGFloat = 0; public var tint: Color? = nil; public init() }`
  - `GlitchPathMenu.init(items:systemImage:variant:gooStyle:configure:onSelect:)` — `variant: GlitchPathMenuVariant = .standard`, `gooStyle: GlitchGooMenuStyle = .init()`, `configure: ((inout PathMenuStyle) -> Void)? = nil` (applied after the wrapper resolves its style; the Goo Lab uses it to override radii, stagger, and spring).
  - `struct GooMenuUnderlay: View` (internal) with the fields shown below.

- [ ] **Step 1: Write the underlay**

Create `Glitch Design System/Glitch/Goo/GooMenuUnderlay.swift`:

```swift
import SwiftUI

/// The liquid beneath a gooey path menu: one disc per petal plus the trigger,
/// merged by the goo shader.
///
/// The petals animate themselves with per-petal `KeyframeAnimator` timelines,
/// so their positions never exist in any one place. Rather than collect them,
/// this view runs a single linear clock per transition and evaluates every
/// petal's position analytically with `Spring.value` — the same spring, the
/// same per-petal delays (`GooMath.menuDelay` mirrors `PetalTimeline.make`) —
/// so discs and icons travel together without either driving the other.
struct GooMenuUnderlay: View {
    var count: Int
    /// Resting offset of each petal from the trigger's centre.
    var anchors: [CGSize]
    var triggerRadius: CGFloat
    var petalRadius: CGFloat
    var spring: Spring
    var duration: Double
    var stagger: Double
    var isOpen: Bool
    var highlightedIndex: Int?
    var smoothing: CGFloat
    var edge: CGFloat
    var fill: Color
    /// Side of the square canvas. Sized by the caller to contain the farthest
    /// overshoot plus a petal and the blend range.
    var extent: CGFloat

    /// The last petal to move plus its spring's settling; the clock runs a
    /// little past the nominal duration so the necks finish snapping.
    private var total: Double {
        duration + stagger * Double(max(count - 1, 0)) + 0.2
    }

    var body: some View {
        KeyframeAnimator(initialValue: total, trigger: isOpen) { elapsed in
            GooSurface(
                blobs: blobs(at: elapsed),
                smoothing: smoothing,
                edge: edge,
                fill: fill
            )
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                LinearKeyframe(0.0, duration: 1e-4)
                LinearKeyframe(total, duration: total)
            }
        }
        .frame(width: extent, height: extent)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func blobs(at elapsed: Double) -> [GooBlob] {
        let centre = CGPoint(x: extent / 2, y: extent / 2)
        var blobs: [GooBlob] = [GooBlob(center: centre, radius: triggerRadius)]

        for index in 0 ..< min(count, anchors.count) {
            let delay = GooMath.menuDelay(
                index: index, count: count, stagger: stagger, opening: isOpen
            )
            let t = elapsed - delay
            // Travel fraction along the petal's ray: 0 at home, 1 at rest,
            // transiently past 1 while the spring overshoots.
            let fraction: Double
            if t <= 0 {
                fraction = isOpen ? 0 : 1
            } else {
                fraction = spring.value(
                    fromValue: isOpen ? 0.0 : 1.0,
                    toValue: isOpen ? 1.0 : 0.0,
                    initialVelocity: 0,
                    time: t
                )
            }
            let radius = petalRadius * (highlightedIndex == index ? 1.14 : 1)
            blobs.append(GooBlob(
                center: CGPoint(
                    x: centre.x + anchors[index].width * fraction,
                    y: centre.y + anchors[index].height * fraction
                ),
                radius: radius
            ))
        }
        return blobs
    }
}
```

- [ ] **Step 2: Extend GlitchPathMenu**

Modify `Glitch Design System/Glitch/Controls/GlitchPathMenu.swift`. The full set of edits:

**2a.** Add the two public types above the `GlitchPathMenu` struct:

```swift
/// Which rendering the themed menu uses.
public enum GlitchPathMenuVariant: Hashable, Sendable {
    /// Discrete petals on the theme's surface — glass where the theme says so.
    case standard
    /// Petals joined to the trigger by a liquid membrane while they travel.
    /// The liquid is a solid shader-drawn fill: Liquid Glass petals cannot
    /// melt into one another, so glass does not apply to this variant.
    case gooey
}

/// The gooey variant's own knobs.
public struct GlitchGooMenuStyle: Sendable {
    /// Blend range of the liquid union, in points.
    public var goo: CGFloat = 18
    /// Extra edge softness in points. Zero is a crisp antialiased edge.
    public var edgeSoftness: CGFloat = 0
    /// Fill of the liquid. `nil` uses the palette's active track.
    public var tint: Color? = nil

    public init() {}
}
```

**2b.** Add the stored properties and the new initializer (replace the existing init; keep source compatibility since the new parameters all default):

```swift
    private let items: [PathMenuItem]
    private let systemImage: String
    private let variant: GlitchPathMenuVariant
    private let gooStyle: GlitchGooMenuStyle
    private let configure: ((inout PathMenuStyle) -> Void)?
    private let onSelect: (PathMenuItem) -> Void

    @State private var isExpanded = false
    /// Which petal the liquid should swell under. Fed by the petal builder's
    /// highlight callback, the one place highlight state surfaces.
    @State private var highlightedIndex: Int?

    public init(
        items: [PathMenuItem],
        systemImage: String = "plus",
        variant: GlitchPathMenuVariant = .standard,
        gooStyle: GlitchGooMenuStyle = .init(),
        configure: ((inout PathMenuStyle) -> Void)? = nil,
        onSelect: @escaping (PathMenuItem) -> Void
    ) {
        self.items = items
        self.systemImage = systemImage
        self.variant = variant
        self.gooStyle = gooStyle
        self.configure = configure
        self.onSelect = onSelect
    }
```

**2c.** In `resolvedStyle`, after the existing assignments and before `return style`, add:

```swift
        if variant == .gooey {
            // The membrane needs an analytic spring to mirror, and the blow-up
            // flourish would tear it, so the gooey menu closes plainly.
            style.motion = .spring(
                response: motion.travelSpring.response,
                dampingRatio: motion.travelSpring.dampingRatio
            )
            style.selectionEffect = .close
            style.rotatesPetals = false
        }
        configure?(&style)
```

**2d.** In `body`, attach the underlay beneath the menu. Wrap the existing `PathMenu(...)` call:

```swift
    public var body: some View {
        let style = resolvedStyle

        PathMenu(
            items: items,
            style: style,
            isExpanded: expansion,
            onSelect: { item in
                GlitchHaptics.impact()
                GlitchSound.commit()
                onSelect(item)
            },
            trigger: { phase in trigger(phase) },
            item: { item, phase in petal(item, phase) }
        )
        .background(alignment: .center) {
            if variant == .gooey {
                gooUnderlay(style: style)
            }
        }
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel("Menu")
    }

    private func gooUnderlay(style: PathMenuStyle) -> some View {
        let geometry = PathMenuGeometry(
            count: items.count,
            nearRadius: style.nearRadius,
            endRadius: style.endRadius,
            farRadius: style.farRadius,
            wholeAngle: style.wholeAngle.radians,
            rotationOffset: style.rotationOffset.radians
        )
        let spring = style.motion.springParameters.map {
            Spring(response: $0.response, dampingRatio: $0.dampingRatio)
        } ?? motion.travelSpring

        return GooMenuUnderlay(
            count: items.count,
            anchors: geometry.anchors.map(\.end),
            triggerRadius: style.triggerDiameter / 2,
            petalRadius: style.petalDiameter / 2,
            spring: spring,
            duration: style.duration,
            stagger: style.stagger,
            isOpen: isExpanded,
            highlightedIndex: highlightedIndex,
            smoothing: gooStyle.goo,
            edge: gooStyle.edgeSoftness,
            fill: gooStyle.tint ?? theme.palette.trackActive,
            // A loosely damped spring can overshoot past farRadius, and a
            // blob crossing the canvas edge would render a flat clipped side.
            extent: 2 * (max(style.farRadius, style.endRadius * 1.4)
                + style.petalDiameter / 2 + gooStyle.goo + 8)
        )
    }
```

Note `resolvedStyle` was previously computed inside `body` implicitly via the property — the body above binds it once so the underlay and the menu use the same values.

**2e.** In `trigger(_:)` and `petal(_:_:)`, draw no disc in the gooey variant — the liquid already has. In `trigger`, replace the `Color.clear.glitchSurface(...)` chain's surface line so the disc only appears in the standard variant:

```swift
    private func trigger(_ phase: PathMenuTriggerPhase) -> some View {
        let diameter = theme.metrics.rowHeight * 1.55

        return Color.clear
            .glitchSurface(Circle(), fill: variant == .gooey
                ? Color.clear
                : phase.isExpanded ? theme.palette.selectionFill : theme.palette.trackActive)
            .frame(width: diameter, height: diameter)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: theme.metrics.iconSize * 1.3, weight: .semibold))
                    .foregroundStyle(phase.isExpanded
                        ? theme.palette.onSelection
                        : theme.palette.label)
            }
            .clipShape(Circle())
    }
```

In `petal`, do the same for the petal's fill, and extend the existing `.onChange(of: phase.isHighlighted)` to also record the index:

```swift
    private func petal(_ item: PathMenuItem, _ phase: PathMenuItemPhase) -> some View {
        let diameter = theme.metrics.rowHeight * 1.25

        return Color.clear
            .glitchSurface(Circle(), fill: variant == .gooey
                ? Color.clear
                : phase.isHighlighted ? theme.palette.selectionFill : theme.palette.trackActive)
            .frame(width: diameter, height: diameter)
            .overlay {
                Image(systemName: item.systemImage)
                    .font(.system(size: theme.metrics.iconSize, weight: .semibold))
                    .foregroundStyle(phase.isHighlighted
                        ? theme.palette.onSelection
                        : theme.palette.label)
            }
            .clipShape(Circle())
            .contentShape(Circle())
            .scaleEffect(phase.isHighlighted ? 1.14 : 1)
            .animation(motion.pop, value: phase.isHighlighted)
            .onChange(of: phase.isHighlighted) { _, highlighted in
                if highlighted {
                    GlitchSound.tick()
                    highlightedIndex = phase.index
                } else if highlightedIndex == phase.index {
                    highlightedIndex = nil
                }
            }
            .accessibilityLabel(item.title)
    }
```

(`.contentShape(Circle())` is new and matters: with a clear fill the petal would otherwise lose its hit area.)

**2f.** Add a preview for the variant at the bottom of the file:

```swift
#Preview("Gooey path menu") {
    GlitchPathMenu(
        items: [
            PathMenuItem(title: "Flow", systemImage: "wind"),
            PathMenuItem(title: "Echo", systemImage: "waveform.path.ecg"),
            PathMenuItem(title: "Noise", systemImage: "aqi.medium"),
            PathMenuItem(title: "Warp", systemImage: "tornado"),
        ],
        variant: .gooey,
        onSelect: { _ in }
    )
    .frame(width: 420, height: 420)
    .background(GlitchPalette.dark.background)
    .glitchTheme()
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 3: Build and run tests**

Run: `cd "/Users/felixjamestin/Documents/Glitch Design System" && swift build 2>&1 | tail -3 && swift test 2>&1 | tail -3`
Expected: `Build complete!`, all suites PASS.

- [ ] **Step 4: Commit**

```bash
cd "/Users/felixjamestin/Documents/Glitch Design System" && git add "Glitch Design System/Glitch/Goo/GooMenuUnderlay.swift" "Glitch Design System/Glitch/Controls/GlitchPathMenu.swift" && git commit -m "Give the path menu a liquid membrane"
```

---

### Task 5: The Goo Lab

**Files:**
- Create: `Glitch Design System/Demo/GooLabView.swift`
- Modify: `Glitch Design System/App/GlitchDesignSystemApp.swift` (tab list and screen switch)

**Interfaces:**
- Consumes: `GlitchGooField`, `GlitchGooFieldStyle`, `GlitchPathMenu` with `variant: .gooey`, `gooStyle:`, `configure:`; demo controls `GlitchPanel`, `GlitchSection`, `GlitchDivider`, `GlitchSlider(_:value:in:step:notches:)`, `GlitchStepper(_:value:in:)`, `GlitchToggle`, `GlitchSwatchRow(swatches:selectedIndex:)`.
- Produces: `struct GooLabView: View` (demo target only).

- [ ] **Step 1: Write the lab**

Create `Glitch Design System/Demo/GooLabView.swift`:

```swift
import SwiftUI

/// Both goo effects on one canvas, with every parameter wired to a control.
///
/// Like the Playground, the point is that the controls drive something live:
/// a slider moving the blend range shows exactly what "goo 24" feels like,
/// which no static preview can.
struct GooLabView: View {
    @Environment(\.glitchTheme) private var theme

    @State private var email = ""
    @State private var submitted: String?

    // Shared liquid
    @State private var goo = 16.0
    @State private var edgeSoftness = 0.0
    @State private var colorIndex = 0

    // Field
    @State private var detachDistance = 16.0
    @State private var buttonDiameter = 34.0

    // Menu
    @State private var gooeyMenu = true
    @State private var petalCount = 5
    @State private var endRadius = 110.0
    @State private var springResponse = 0.42
    @State private var springDamping = 0.72
    @State private var staggerMs = 36.0

    @State private var containerWidth: CGFloat = 0

    private let palette: [(color: Color, label: String)] = [
        (GlitchPalette.signatureAccent, "Ember"),
        (Color(glitchHex: 0xFF9F1C), "Amber"),
        (Color(glitchHex: 0x4ECDC4), "Mint"),
        (Color(glitchHex: 0x9B5DE5), "Violet"),
    ]

    private let allItems = [
        PathMenuItem(title: "Flow", systemImage: "wind"),
        PathMenuItem(title: "Echo", systemImage: "waveform.path.ecg"),
        PathMenuItem(title: "Noise", systemImage: "aqi.medium"),
        PathMenuItem(title: "Warp", systemImage: "tornado"),
        PathMenuItem(title: "Trim", systemImage: "scissors"),
        PathMenuItem(title: "Seed", systemImage: "leaf"),
        PathMenuItem(title: "Fold", systemImage: "arrow.triangle.merge"),
        PathMenuItem(title: "Melt", systemImage: "drop"),
    ]

    private var isWide: Bool { containerWidth > 760 }
    private var tint: Color { palette[colorIndex].color }

    var body: some View {
        Group {
            if isWide {
                HStack(alignment: .top, spacing: 16) {
                    canvas
                    panel.frame(width: 320)
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        canvas.frame(height: 420)
                        panel
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
    }

    private var canvas: some View {
        VStack(spacing: 0) {
            GlitchGooField(
                text: $email,
                placeholder: "Enter your email",
                style: fieldStyle
            ) { value in
                submitted = value
                email = ""
            }
            .frame(width: 300)
            .padding(.top, 48)

            if let submitted {
                Text("Sent to \(submitted)")
                    .font(.system(size: theme.metrics.labelSize))
                    .foregroundStyle(theme.palette.labelSecondary)
                    .padding(.top, 12)
            }

            Spacer()

            // Centred in the remaining space so the full circle of petals has
            // room on every side; its layout footprint is only the trigger.
            GlitchPathMenu(
                items: Array(allItems.prefix(petalCount)),
                variant: gooeyMenu ? .gooey : .standard,
                gooStyle: menuGooStyle,
                configure: { style in
                    style.endRadius = endRadius
                    style.nearRadius = endRadius * 0.92
                    style.farRadius = endRadius * 1.17
                    style.stagger = staggerMs / 1000
                    style.motion = .spring(
                        response: springResponse,
                        dampingRatio: springDamping
                    )
                },
                onSelect: { _ in }
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: theme.metrics.panelRadius, style: .continuous)
                .fill(Color.black.opacity(0.35))
        }
        .overlay {
            RoundedRectangle(cornerRadius: theme.metrics.panelRadius, style: .continuous)
                .strokeBorder(theme.palette.stroke, lineWidth: 1)
        }
    }

    private var fieldStyle: GlitchGooFieldStyle {
        var style = GlitchGooFieldStyle()
        style.goo = goo
        style.detachDistance = detachDistance
        style.buttonDiameter = buttonDiameter
        style.edgeSoftness = edgeSoftness
        style.spring = Spring(response: springResponse, dampingRatio: springDamping)
        style.tint = tint
        return style
    }

    private var menuGooStyle: GlitchGooMenuStyle {
        var style = GlitchGooMenuStyle()
        style.goo = goo
        style.edgeSoftness = edgeSoftness
        style.tint = tint
        return style
    }

    private var panel: some View {
        ScrollView {
            GlitchPanel {
                GlitchSection("Liquid") {
                    GlitchSlider("Goo", value: $goo, in: 0...40)
                    GlitchSlider("Edge softness", value: $edgeSoftness, in: 0...12, step: 0.5)
                }

                GlitchDivider()

                GlitchSection("Field") {
                    GlitchSlider("Detach", value: $detachDistance, in: 0...60)
                    GlitchSlider("Button size", value: $buttonDiameter, in: 20...48)
                }

                GlitchDivider()

                GlitchSection("Menu") {
                    GlitchToggle("Gooey", isOn: $gooeyMenu)
                    GlitchStepper("Petals", value: $petalCount, in: 1...8)
                    GlitchSlider("Radius", value: $endRadius, in: 60...180)
                    GlitchSlider("Response", value: $springResponse, in: 0.2...1.0, step: 0.01, decimals: 2)
                    GlitchSlider("Damping", value: $springDamping, in: 0.3...1.0, step: 0.01, decimals: 2)
                    GlitchSlider("Stagger", value: $staggerMs, in: 0...120)
                }

                GlitchDivider()

                GlitchSwatchRow(swatches: palette, selectedIndex: $colorIndex)
            }
        }
        .scrollIndicators(.never)
    }
}

#Preview {
    GooLabView()
        .glitchTheme()
        .glitchMotion()
        .preferredColorScheme(.dark)
        .frame(width: 1000, height: 700)
}
```

- [ ] **Step 2: Add the tab**

Modify `Glitch Design System/App/GlitchDesignSystemApp.swift`. In `RootView`, extend the tab list:

```swift
    private let tabs = [
        GlitchTabItem(id: 0, title: "Playground", systemImage: "slider.horizontal.3"),
        GlitchTabItem(id: 1, title: "Gallery", systemImage: "square.grid.2x2"),
        GlitchTabItem(id: 2, title: "Motion Lab", systemImage: "waveform.path"),
        GlitchTabItem(id: 3, title: "Goo Lab", systemImage: "drop"),
    ]
```

And in `screen`, make Motion Lab an explicit case with the new tab as a new case (keeping the existing `default` as the last screen so an out-of-range selection still renders something):

```swift
        case 2:
            MotionLabView(
                motionScale: $motionScale,
                forceReduceMotion: $forceReduceMotion
            )
        default:
            GooLabView()
```

- [ ] **Step 3: Build and run the full test suite**

Run: `cd "/Users/felixjamestin/Documents/Glitch Design System" && swift build 2>&1 | tail -3 && swift test 2>&1 | tail -3`
Expected: `Build complete!`, all suites PASS.

- [ ] **Step 4: Commit**

```bash
cd "/Users/felixjamestin/Documents/Glitch Design System" && git add "Glitch Design System/Demo/GooLabView.swift" "Glitch Design System/App/GlitchDesignSystemApp.swift" && git commit -m "Open a lab for playing with the goo"
```

---

### Task 6: Visual verification in the running app

The shader, the bud-off, and the membrane can only be judged on screen. This
task produces evidence, not code.

- [ ] **Step 1: Launch the demo app** (macOS scheme of `Glitch Design System.xcodeproj`, or previews if the app cannot be driven) and open the Goo Lab tab.
- [ ] **Step 2: Verify, and screenshot each state:**
  - The field at rest is a plain capsule; no white rectangle (a white rectangle means the metallib was not found — revisit Task 2's lookup).
  - Focusing the field detaches the arrow button with a visible stretching neck; blurring merges it back.
  - Opening the menu shows petals pulling liquid necks from the trigger that snap as petals separate; closing reverses it.
  - The goo slider at 0 gives hard separate discs; large values melt them together. Every other slider visibly changes what it names.
  - Toggling "Gooey" off shows the standard solid menu unchanged.
- [ ] **Step 3: Fix what the screenshots contradict** — geometry offsets, z-order, timing mismatches between icons and discs — committing fixes with messages naming what was wrong.
