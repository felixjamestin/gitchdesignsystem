# Glitch Design System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a custom SwiftUI control library — 15 controls plus inspector chrome — that looks and feels identical on macOS and iOS, driven by a token-based motion system, with a three-tab demo app.

**Architecture:** Controls are drawn from shapes and gestures rather than restyling native controls (except `TextField`, which is wrapped). Platform difference is absorbed by a density environment value, a cross-platform hover modifier, and input parity — not by `#if os()` branches in control bodies. All value/geometry math is extracted into pure, SwiftUI-free files so it can be unit-tested.

**Tech Stack:** SwiftUI, Swift 5 language mode, Swift Testing via SPM, Xcode file-system-synchronized project group.

## Global Constraints

- Deployment targets are iOS 27.0 / macOS 27.0 but the **installed SDK is 26.5**. Write against iOS/macOS 26-era APIs only. Do not raise the API ceiling.
- Swift language mode stays **5.0**. Do not migrate to Swift 6 concurrency.
- Public types are prefixed `Glitch`.
- **No ad-hoc animations.** Every animation comes from a `GlitchMotion` token.
- **No `#if os(...)` inside control bodies.** Platform branching is confined to `Glitch/Motion/` and `GlitchDensity.platformDefault`.
- Files under `Glitch Design System/` are auto-compiled by the synchronized group. **Never edit `project.pbxproj`.**
- Files under `Glitch/Math/` must import only `Foundation`/`CoreGraphics` — never SwiftUI — and must be `public`, because the SPM test target compiles them.
- Every custom-drawn control declares accessibility traits, a value, and where relevant an adjustable action.
- Build verification: `xcodebuild -scheme "Glitch Design System" -destination 'platform=macOS' build`
- Test verification: `swift test`

---

## File Structure

```
Package.swift                              # SPM manifest, points at Glitch/Math for tests only
Tests/GlitchMathTests/*.swift              # Swift Testing suites

Glitch Design System/
  App/
    GlitchDesignSystemApp.swift            # @main + 3-tab RootView
  Glitch/
    Math/                                  # pure, no SwiftUI, public, SPM-compiled
      GlitchValueMath.swift
      GlitchNumberParsing.swift
      GlitchAngleMath.swift
    Tokens/
      GlitchDensity.swift                  # density enum + metrics
      GlitchPalette.swift                  # light/dark colors
      GlitchTheme.swift                    # theme struct + environment + .glitchTheme()
      GlitchType.swift                     # text styles
    Motion/
      GlitchMotion.swift                   # 4 spring tokens + reduce-motion + scale
      ControlState.swift                   # flags struct + style resolution
      Interaction.swift                    # .glitchHover, .glitchPressable
      Haptics.swift                        # iOS haptics, no-op elsewhere
    Controls/
      GlitchSlider.swift
      GlitchDragField.swift
      GlitchTextField.swift                # + GlitchSearchField
      GlitchToggle.swift                   # + GlitchCheckbox
      GlitchRadioGroup.swift
      GlitchButton.swift
      GlitchSegmented.swift
      GlitchStepper.swift
      GlitchSwatch.swift
      GlitchSelect.swift
      GlitchChips.swift
      GlitchXYPad.swift
      GlitchDial.swift
    Chrome/
      GlitchPanel.swift                    # panel + section + divider
  Demo/
    PlaygroundView.swift
    GlitchCanvas.swift
    GalleryView.swift
    MotionLabView.swift
```

---

### Task 1: Test harness and pure value math

**Files:**
- Create: `Package.swift`, `Glitch Design System/Glitch/Math/GlitchValueMath.swift`
- Test: `Tests/GlitchMathTests/GlitchValueMathTests.swift`

**Interfaces — Produces:**
```swift
public enum GlitchValueMath {
    public static func clamp(_ v: Double, to r: ClosedRange<Double>) -> Double
    public static func normalize(_ v: Double, in r: ClosedRange<Double>) -> Double
    public static func denormalize(_ t: Double, in r: ClosedRange<Double>) -> Double
    public static func snap(_ v: Double, step: Double, in r: ClosedRange<Double>) -> Double
    public static func fraction(ofX x: Double, width: Double) -> Double
    public static func rubberBand(_ overshoot: Double, dimension: Double, coefficient: Double = 0.55) -> Double
}
```

- [ ] **Step 1: Write `Package.swift`** pointing the `GlitchMath` target at the app's Math folder so tests compile the real files.
- [ ] **Step 2: Write failing tests** covering: clamping below/above/inside; normalize on a degenerate range returns 1.0 rather than NaN; `fraction(ofX:width:)` with width 0 returns 0; snap rounds to nearest step and stays in range; step ≤ 0 clamps only; rubber-band is monotonic, sub-linear, and returns 0 at 0.
- [ ] **Step 3: Run `swift test`** — expect failure (no such module / no such symbol).
- [ ] **Step 4: Implement `GlitchValueMath`** with the degenerate-range and zero-width guards from spec §6.
- [ ] **Step 5: Run `swift test`** — expect pass.
- [ ] **Step 6: Verify the app still builds** with `xcodebuild ... -destination 'platform=macOS' build`.
- [ ] **Step 7: Commit.**

### Task 2: Number parsing and angle math

**Files:**
- Create: `Glitch/Math/GlitchNumberParsing.swift`, `Glitch/Math/GlitchAngleMath.swift`
- Test: `Tests/GlitchMathTests/GlitchNumberParsingTests.swift`, `Tests/GlitchMathTests/GlitchAngleMathTests.swift`

**Interfaces — Produces:**
```swift
public enum GlitchNumberParsing {
    public static func parse(_ s: String, fallback: Double) -> Double
    public static func format(_ v: Double, decimals: Int) -> String
}
public enum GlitchAngleMath {
    public static func value(forAngle radians: Double, sweep: Double, in r: ClosedRange<Double>) -> Double
    public static func angle(forValue v: Double, sweep: Double, in r: ClosedRange<Double>) -> Double
    public static func shortestDelta(from a: Double, to b: Double) -> Double
}
```

- [ ] **Step 1: Write failing tests.** Parsing: plain integers, decimals, leading/trailing whitespace, a leading `+`, empty string → fallback, pure garbage → fallback, `"12px"` → 12. Angle: value↔angle round-trips, the wrap discontinuity across ±π takes the short way, sweep of 0 does not divide by zero.
- [ ] **Step 2: Run `swift test`** — expect failure.
- [ ] **Step 3: Implement both enums.**
- [ ] **Step 4: Run `swift test`** — expect pass.
- [ ] **Step 5: Commit.**

### Task 3: Design tokens

**Files:**
- Create: `Glitch/Tokens/GlitchDensity.swift`, `GlitchPalette.swift`, `GlitchTheme.swift`, `GlitchType.swift`

**Interfaces — Produces:**
```swift
enum GlitchDensity { case compact, comfortable; static var platformDefault: GlitchDensity }
struct GlitchMetrics {   // resolved from density
    var rowHeight, controlRadius, panelRadius, hInset, spacing, panelPadding: CGFloat
    var knobWidth, iconSize, labelSize, valueSize, swatchSize: CGFloat
    static func resolve(_ d: GlitchDensity) -> GlitchMetrics
}
struct GlitchPalette { /* background, panel, track, trackHover, trackActive,
                          label, labelSecondary, stroke, accent, danger */
    static let dark: GlitchPalette; static let light: GlitchPalette }
struct GlitchTheme { var palette: GlitchPalette; var accent: Color; var metrics: GlitchMetrics }
extension EnvironmentValues { @Entry var glitchTheme: GlitchTheme; @Entry var glitchDensity: GlitchDensity }
extension View { func glitchTheme(accent: Color? = nil, density: GlitchDensity? = nil) -> some View }
```

Exact values — compact: row 28, radius 9, inset 10, spacing 6, label 10, value 11, knob 2.
Comfortable: row 44, radius 12, inset 14, spacing 10, label 12, value 13, knob 2.5.
Dark palette: background `#1B1B1D`, panel `#232326`, track `#3A3A3E`, trackHover `#45454A`,
trackActive `#4E4E54`, label `#ECECEE`, labelSecondary `#95959C`, stroke white 8%,
accent `#FF5A1F`, danger `#FF4444`. Light palette is the tonal inverse with the same accent.

- [ ] **Step 1:** Implement density + metrics.
- [ ] **Step 2:** Implement palette (both schemes) and typography helpers (uppercase label style with tracking, tabular-figure value style).
- [ ] **Step 3:** Implement `GlitchTheme`, its environment entries, and the `.glitchTheme()` modifier that resolves the palette from `\.colorScheme`.
- [ ] **Step 4:** Build for macOS — expect success.
- [ ] **Step 5: Commit.**

### Task 4: Motion system and control state

**Files:**
- Create: `Glitch/Motion/GlitchMotion.swift`, `ControlState.swift`, `Interaction.swift`, `Haptics.swift`

**Interfaces — Produces:**
```swift
struct GlitchMotion {                    // resolved from scale + reduce-motion
    var snap, glide, pop, drift: Animation
    static func resolve(scale: Double, reduceMotion: Bool) -> GlitchMotion
}
extension EnvironmentValues { @Entry var glitchMotion: GlitchMotion; @Entry var glitchMotionScale: Double }
extension View { func glitchMotionScale(_ s: Double) -> some View }

struct ControlState: Equatable {   // independent flags, per spec §5
    var isHovering, isPressed, isFocused, isDragging, isDisabled, isErrored: Bool
    func trackFill(_ p: GlitchPalette) -> Color
    var pressScale: CGFloat
    var opacity: Double
}
extension View {
    func glitchHover(_ onChange: @escaping (Bool) -> Void) -> some View
    func glitchPressable(isPressed: Binding<Bool>, onTap: @escaping () -> Void) -> some View
}
enum GlitchHaptics { static func tick(); static func selection(); static func impact() }
```

Springs: snap `.spring(response: 0.18, dampingFraction: 0.86)`, glide `0.32 / 0.82`,
pop `0.28 / 0.68`, drift `0.50 / 1.00`. Each response is multiplied by `scale`.
Reduce-motion resolves all four to `.easeOut(duration: 0.10 * scale)`.

- [ ] **Step 1:** Implement `GlitchMotion.resolve` with the four tokens and the reduce-motion collapse.
- [ ] **Step 2:** Implement `ControlState` and its style resolution (precedence: disabled > errored > dragging > pressed > hovering > focused).
- [ ] **Step 3:** Implement `.glitchHover` (real hover on macOS/iPad pointer, no-op on iPhone) and `.glitchPressable` (press-in on touch-down via a 0-distance `DragGesture`, commit on release only if still inside).
- [ ] **Step 4:** Implement `GlitchHaptics` — `#if os(iOS)` real feedback, no-op elsewhere. This is one of the two files permitted to branch on platform.
- [ ] **Step 5:** Build for macOS — expect success.
- [ ] **Step 6: Commit.**

### Task 5: `GlitchSlider` — the hero control

**Files:**
- Create: `Glitch/Controls/GlitchSlider.swift`

**Interfaces — Consumes:** `GlitchValueMath`, `GlitchMotion`, `ControlState`, `GlitchTheme`.
**Produces:** `GlitchSlider(label:value:in:step:defaultValue:decimals:)`.

Anatomy: rounded-rect track (`metrics.controlRadius`) filled `palette.track`; accent fill from the
left clipped to the same shape; uppercase label inset left; a `knobWidth` vertical line at the value;
value right-aligned with tabular figures; hover-revealed `⊗` reset at the label's left when
`value != defaultValue`.

- [ ] **Step 1:** Render the static anatomy with a `GeometryReader`-measured track.
- [ ] **Step 2:** Add drag: jump-and-grab on touch-down anywhere in the track; **no animation during drag** (rule 7); `glide` spring on release.
- [ ] **Step 3:** Add ⇧-fine-drag (0.1×) and rubber-band past the limits via `GlitchValueMath.rubberBand`.
- [ ] **Step 4:** Add the hover-revealed reset, ⌥-click reset, and long-press reset for touch.
- [ ] **Step 5:** Add keyboard (`←`/`→` ±1 step, `⇧` ±10) and scroll-wheel adjustment, plus a focus ring.
- [ ] **Step 6:** Add the haptic tick and value-label pop on step crossings.
- [ ] **Step 7:** Add accessibility: `.isAdjustable` trait, `accessibilityValue`, and increment/decrement actions.
- [ ] **Step 8:** Build for macOS — expect success. **Commit.**

### Task 6: `GlitchDragField`

**Files:** Create `Glitch/Controls/GlitchDragField.swift`
**Consumes:** `GlitchNumberParsing`, `GlitchValueMath`. **Produces:** `GlitchDragField(label:value:in:step:decimals:)`.

- [ ] **Step 1:** Render label + value row with a horizontal-resize cursor on hover (macOS).
- [ ] **Step 2:** Horizontal drag scrubs the value at `step` per 4pt, `⇧` for 0.1× precision.
- [ ] **Step 3:** Click (a drag under 3pt) swaps to an editable `TextField`; commit parses via `GlitchNumberParsing.parse` with the current value as fallback; `⎋` cancels.
- [ ] **Step 4:** Accessibility adjustable action. Build. **Commit.**

### Task 7: Text and search fields

**Files:** Create `Glitch/Controls/GlitchTextField.swift`
**Produces:** `GlitchTextField(label:text:placeholder:error:)`, `GlitchSearchField(text:placeholder:)`.

- [ ] **Step 1:** Wrap `TextField(...).textFieldStyle(.plain)` in the standard track chrome; focus ring via `@FocusState` animating with `snap`.
- [ ] **Step 2:** Error state — `palette.danger` stroke plus a message that animates in below the field with `pop`, without shifting sibling layout.
- [ ] **Step 3:** `GlitchSearchField` — magnifier icon, and a clear button that appears with `pop` only when non-empty.
- [ ] **Step 4:** Build. **Commit.**

### Task 8: Toggle, checkbox, radio group

**Files:** Create `Glitch/Controls/GlitchToggle.swift`, `GlitchRadioGroup.swift`
**Produces:** `GlitchToggle(label:isOn:)`, `GlitchCheckbox(label:isOn:)`, `GlitchRadioGroup(label:selection:options:)`.

- [ ] **Step 1:** Toggle — knob travels with `snap`, track cross-fades to accent, knob squashes slightly while pressed and releases. Haptic on change.
- [ ] **Step 2:** Checkbox — the checkmark draws in via a trimmed `Path` rather than fading, with `snap`.
- [ ] **Step 3:** Radio group — inner dot scales from 0 with `snap`; the whole row is the hit target.
- [ ] **Step 4:** All three: `.isButton`/`.isSelected` traits and correct `accessibilityValue`. Build. **Commit.**

### Task 9: Button, segmented, stepper, swatch

**Files:** Create `Glitch/Controls/GlitchButton.swift`, `GlitchSegmented.swift`, `GlitchStepper.swift`, `GlitchSwatch.swift`

- [ ] **Step 1:** `GlitchButton(_:style:action:)` with `.primary`/`.secondary`/`.ghost`; press scales to 0.97 with `snap`, hover lifts the fill.
- [ ] **Step 2:** `GlitchSegmented(selection:options:)` — indicator slides via `matchedGeometryEffect` with `glide`; never cross-fades.
- [ ] **Step 3:** `GlitchStepper(label:value:in:step:)` — `−`/`+` with press-repeat that accelerates after 0.5s.
- [ ] **Step 4:** `GlitchSwatch(color:isSelected:)` — selection ring scales in with `pop`.
- [ ] **Step 5:** Build. **Commit.**

### Task 10: `GlitchSelect` and `GlitchChips`

**Files:** Create `Glitch/Controls/GlitchSelect.swift`, `GlitchChips.swift`

`GlitchSelect` uses a custom anchored popover on **both** platforms (spec §5) — not SwiftUI `Menu`.

- [ ] **Step 1:** Closed state — label, current selection, chevron that rotates 180° with `snap` on open.
- [ ] **Step 2:** Popover presented in an overlay, scaling from the anchor edge with `pop` (rule 4), dismissing on outside tap and on `⎋`.
- [ ] **Step 3:** Keyboard navigation — `↑`/`↓` move the highlight, `↩` selects, `⎋` dismisses.
- [ ] **Step 4:** Empty-options guard (spec §6): render a disabled "No options" row, never crash.
- [ ] **Step 5:** `GlitchChips` — removable tokens; insertion/removal via `pop` with `.transition(.scale.combined(with: .opacity))`.
- [ ] **Step 6:** Build. **Commit.**

### Task 11: `GlitchXYPad` and `GlitchDial`

**Files:** Create `Glitch/Controls/GlitchXYPad.swift`, `GlitchDial.swift`
**Consumes:** `GlitchAngleMath`, `GlitchValueMath`.

- [ ] **Step 1:** XY pad — square field, crosshair guides, a knob tracking the finger 1:1 with no animation during drag, springing with `glide` on release. Clamped to bounds.
- [ ] **Step 2:** Dial — arc track with accent progress arc; drag rotates using `GlitchAngleMath.shortestDelta` so it cannot jump across the wrap point; haptic tick on step crossings.
- [ ] **Step 3:** Both: adjustable accessibility actions. Build. **Commit.**

### Task 12: Inspector chrome

**Files:** Create `Glitch/Chrome/GlitchPanel.swift`
**Produces:** `GlitchPanel { }`, `GlitchSection(title:) { }`, `GlitchDivider()`.

- [ ] **Step 1:** `GlitchPanel` — panel fill, `panelRadius`, hairline stroke, `panelPadding`.
- [ ] **Step 2:** `GlitchSection` — collapsible with the reference's chevron, expanding with `drift`; content clipped so it does not overflow while collapsing.
- [ ] **Step 3:** `GlitchDivider` — hairline at true pixel width. Build. **Commit.**

### Task 13: Demo — app shell, Playground, and canvas

**Files:**
- Create: `App/GlitchDesignSystemApp.swift`, `Demo/PlaygroundView.swift`, `Demo/GlitchCanvas.swift`
- Delete: `Glitch Design System/ContentView.swift`

- [ ] **Step 1:** Delete `ContentView.swift`; create the `@main` app with a three-tab `RootView` (Playground · Gallery · Motion Lab) that applies `.glitchTheme()` at the root.
- [ ] **Step 2:** `GlitchCanvas` — a `TimelineView` + `Canvas` particle/flow field whose flow, noise, speed, echoes, tension, and color are driven by bindings.
- [ ] **Step 3:** `PlaygroundView` — canvas beside a `GlitchPanel` of real controls bound to the canvas parameters, echoing the first reference image's parameter list. Adaptive layout: side-by-side when wide, stacked when narrow.
- [ ] **Step 4:** Build and run on macOS; confirm controls visibly drive the canvas. **Commit.**

### Task 14: Demo — Gallery and Motion Lab

**Files:** Create `Demo/GalleryView.swift`, `Demo/MotionLabView.swift`

- [ ] **Step 1:** Gallery — every control grouped by type, each shown in idle / focused / disabled / error, with a density switch so `.compact` and `.comfortable` can be compared live.
- [ ] **Step 2:** Motion Lab — a `GlitchSlider` bound to `glitchMotionScale` (1.0 → 0.1×), a Reduce Motion override switch, and a row of controls to exercise while slowed.
- [ ] **Step 3:** Build for macOS **and** for the iOS simulator; verify both densities. **Commit.**

### Task 15: Verification pass

- [ ] **Step 1:** Run `swift test` — all math suites pass.
- [ ] **Step 2:** Build for macOS and iOS Simulator; confirm zero warnings from our own code.
- [ ] **Step 3:** Grep for violations: any `.animation(` or `withAnimation(` using a literal spring/duration outside `GlitchMotion.swift`, and any `#if os(` outside `Motion/` and `GlitchDensity.swift`. Fix what turns up.
- [ ] **Step 4:** Launch on the iOS simulator and screenshot all three tabs.
- [ ] **Step 5: Commit.**

---

## Self-Review

**Spec coverage:** §1 baseline → Global Constraints. §2 architecture → File Structure, Tasks 3–12.
§3 platform → Tasks 3, 4 (density, hover, input parity in Task 5 step 5). §4 motion → Task 4, applied
throughout; rule 7 explicit in Tasks 5 and 11; rule 10 in Task 4 step 1 and Task 14 step 2.
§5 roster → Tasks 5–12, all 15 controls plus 3 chrome components accounted for. §6 correctness →
Task 1 (degenerate range, zero width), Task 10 step 4 (empty options), Task 7 step 2 (text errors).
§7 testing → Tasks 1, 2, 15. §8 demo → Tasks 13, 14. §9 done → Task 15.

**Type consistency:** `GlitchValueMath`, `GlitchNumberParsing`, `GlitchAngleMath`, `GlitchMotion`,
`ControlState`, `GlitchTheme`, `GlitchMetrics`, `GlitchPalette` are each defined once in Tasks 1–4
and referenced by those exact names thereafter.
