# Gooey Effects — Design

**Date:** 2026-08-15
**Status:** Awaiting review
**Scope:** Two liquid-merge ("gooey") effects for the design system — a text field that sheds a
submit button, and a gooey surface variant for the existing radial menu — plus the shared rendering
layer beneath them and a parameter lab for tuning both.

**Reference:** `gooey.jakubantalik.com` (Liquid Gooey, a React library).

## Goal

Add the two effects from the reference to the system, each with enough exposed parameters to be
tuned by hand rather than accepted as authored. The effects must degrade to the plain controls when
the machinery is unavailable, and must not impose per-frame cost on the controls that do not use
them.

## What the reference does

Read off the live filter definitions on that page, the technique is a classic SVG gooey filter with
edge lighting layered on top:

```
feGaussianBlur stdDeviation=6            blur the alpha
feColorMatrix  alpha: a*18 - 7           threshold it — this is the merge
feComposite    SourceGraphic atop goo    crisp content over the merged silhouette
feColorMatrix  alpha: a*60 - 29.5        binarize again → hard mask
feMorphology   erode 1  → inner rim highlight, white 4%
feOffset       dy 1     → second highlight, white 3%
feMorphology   dilate 1 → outer shadow, black 6%
feMerge
```

Its two exposed knobs, `blur` and `contrast`, are the blur radius and the alpha multiplier. Both
effects on the page are the same filter over different content:

- **Input field.** On focus, a circular submit button separates from the trailing end of a capsule,
  joined by a liquid bridge that necks and breaks. Typing does not affect the effect; focus does.
- **Plus button.** Petals fan out radially from a `+` trigger that becomes `×`, bonded to one
  another and to the trigger while they travel.

## Rendering approach

Three candidates were considered.

| | Per-frame cost | Fidelity | Arbitrary content |
|---|---|---|---|
| **A. Analytic SDF in a Metal `colorEffect`** | One fragment pass over the control's bounds. Tens of ALU ops per pixel, no texture taps, no offscreen | Exact, resolution-independent, bridge neck controlled independently of edge softness | No |
| **B. Blur + threshold (port of the filter above)** | Offscreen composite of the children, separable Gaussian, threshold pass | Matches the reference exactly, artifacts included | Yes |
| **C. `GlassEffectContainer` merging** | Apple's own, GPU-optimised | Glass, not opaque goo; no parameters | Yes |

**Both A and B ship, selectable at runtime** via `GlitchGooStyle.renderer`. A is the default.

A is right for this system because the shapes are known analytically. Both effects are circles and
capsules, and `PathMenuGeometry` / `PetalPath.point(at:)` already yield exact petal positions as a
pure function of progress. Per pixel: `d = smin(sdCircle₀, sdCircle₁, …, k)`, then fill, rim and
shadow are all read off that single distance — the `erode` and `dilate` passes become exact band
tests, and `smin`'s `k` controls the neck thickness independently, where blur-and-threshold couples
it to the blur radius.

B is not merely an A/B toy. It is the fallback wherever the compiled shader is unavailable (see
*Shader packaging*), and it is the only path that could gooify arbitrary child views if that is ever
wanted.

C is rejected as a renderer but is already reachable through the existing `PathMenuSurface`
glass cases, which are unaffected by this work.

**A note on cost.** B forces exactly the per-frame offscreen composite that `PathMenuPetal`'s
`animatesEmphasis` goes out of its way to avoid, and that `GlitchPathMenu` avoids again by pinning
`glassBlendSpacing` to zero. Choosing B is choosing that cost knowingly; the default must be A.

## Shader packaging — resolved

**Outcome (2026-08-15): option 1 works.** The build-tool plugin compiles the shader, and its output
is copied into the resource bundle — but *only* because the manifest also declares the shader source
as a resource, since SwiftPM copies plugin output into a bundle it is already creating and will not
create one on the plugin's account. Verified from both directions: `Bundle.module` contains
`default.metallib` after `swift build`, and the app bundle contains one at `Contents/Resources/`
after `xcodebuild`, so `ShaderLibrary.bundle(.module)` and `ShaderLibrary.default` each resolve on
their own side. Neither fallback below is needed. The reasoning that led there is kept as written:



**The `#if SWIFT_PACKAGE` shim proposed during brainstorming does not work**, and this was verified
rather than assumed:

- A `.metal` file left undeclared in an SPM target is reported as unhandled and ignored.
- Declared as `.process(...)`, the **source** is copied into the resource bundle. No
  `default.metallib` is produced, so `ShaderLibrary.bundle(.module)` resolves nothing at runtime.
- Runtime compilation via `MTLDevice.makeLibrary(source:)` does not help: SwiftUI's `Shader` can
  only draw from a `ShaderLibrary`, and there is no public route from an `MTLLibrary` to one.
- The `xcrun metal` / `metallib` toolchain does compile a `[[stitchable]]` kernel including
  `<SwiftUI/SwiftUI_Metal.h>`, so compiling it ourselves is viable.

Resolution, in order of preference:

1. **SwiftPM build-tool plugin** that runs `xcrun metal` + `metallib` and emits `default.metallib`
   into the target's resources. Compiles per platform from the build environment, nothing checked
   in. Costs one plugin target and a trust prompt for consumers in Xcode.
2. **Prebuilt metallibs checked in** as resources, one per platform triple. Simple, but a build
   artifact in the repository and a manual regeneration step whenever the shader changes — against
   the grain of a repository whose manifest exists specifically so there is "one copy, no
   mirroring".
3. **App target only.** The demo compiles the `.metal` through its synchronized group and uses
   `ShaderLibrary.default`; SPM consumers demote to renderer B. Works immediately, but makes the
   headline effect quietly slower for every consumer, which is not an acceptable shipping story.

**Decision: attempt 1, spike it first.** It is the first implementation task, before any control
work, because its outcome determines nothing else in the design but would be expensive to retrofit.
If the plugin proves troublesome, fall back to 3 as an interim while 2 is prepared — the renderer
switch makes that degradation graceful rather than broken.

Whichever lands, `GlitchShaderLibrary` is the single place that resolves the library and the single
place that reports whether the shader is available.

## Architecture

### Shared layer — `Glitch/Goo/`

| File | Responsibility |
|---|---|
| `GlitchGoo.metal` | One `[[stitchable]]` `colorEffect` kernel: `smin` over a packed shape array, shading fill / rim / shadow from the resulting distance. Plus a small threshold kernel for renderer B. |
| `GlitchGooShape.swift` | `GooShape` — circle or capsule as centre, size, corner radius — and its packing into the flat `float` array the kernel reads. Pure; no SwiftUI. |
| `GlitchGooStyle.swift` | Every parameter as an `Equatable, Sendable` struct, with presets, an `@Entry` environment value and a `.glitchGooStyle(_:)` modifier — the conventions `PathMenuStyle` already establishes. |
| `GlitchGooLayer.swift` | Renders `[GooShape]` through whichever backend is in force: `.sdf`, `.blurThreshold`, or `.plain` (shapes drawn unmerged). |
| `GlitchShaderLibrary.swift` | Resolves the shader library and answers whether the SDF path is available. |

`GooShape` packing and the `smin` maths belong under the existing rule for `Glitch/Math/`: pure,
SwiftUI-free, public, unit-tested. They live in `Glitch/Goo/` for cohesion but obey the same
constraint.

### Backend selection

`.sdf` is used when the style asks for it **and** `GlitchShaderLibrary` reports the function
resolved. `.blurThreshold` is used when asked for, or when `.sdf` was asked for and is unavailable.
`.plain` is used when `glitchDelight` is off — goo is an embellishment, and embellishment is what
that switch governs. As everywhere else in the system, the switch changes how a control looks and
never what it can do: the field submits and the menu selects identically in all three.

### `GlitchGooField` — new control

`Glitch/Controls/GlitchGooField.swift`, a sibling to `GlitchTextField` and `GlitchSearchField`
rather than a mode of either. Its anatomy genuinely differs — a capsule with a shed action button,
no inline label row — and one control carrying both would be the kind of type that has to explain
itself.

It wraps the platform `TextField` for exactly the reason `GlitchTextField` gives: reimplementing
selection, input methods and autocorrect would be strictly worse than what the platform does. Theme,
motion, delight and `isEnabled` are read the same way every other control reads them.

### Radial menu — a surface variant

- `PathMenuSurface` gains `.gooey`; `PathMenuStyle` gains `var goo: GlitchGooStyle`.
- The goo layer draws behind the trigger and petals, sized explicitly from `endRadius`, petal radius
  and shadow extent — the menu's layout footprint is only its trigger, the same constraint that
  makes `scrimExtent` an explicit number.
- **One structural change, confined to the goo path.** Renderer A needs petal positions per frame,
  which the petals currently own privately. A single container-level `KeyframeAnimator` drives one
  master clock; each petal's progress is derived as `clamp((t·total − delay) / duration)`, and both
  the petal offsets and the shader's shape array read from it. One source of truth, so the blob
  cannot drift from the icon it is drawn around.
- `PathMenuPetal` gains an externally-driven mode. **Solid and glass surfaces keep today's
  self-animating architecture unchanged**, so nothing already tuned regresses. The cost is two paths
  through the petal until the gooey variant has proved itself.
- `GlitchPathMenu` exposes the surface, supplies theme colours, and folds goo under the delight
  switch alongside `selectionEffect` and `rotatesPetals`.

## Parameters

**Shared — `GlitchGooStyle`:**

| Parameter | Meaning |
|---|---|
| `renderer` | `.sdf` / `.blurThreshold` / `.plain` |
| `blend` | `smin` k — bridge neck thickness. Maps to blur radius under B, so the control means the same thing in both |
| `crispness` | Edge hardness. Maps to the alpha multiplier — the reference's "contrast" |
| `edgeSoftness` | Antialias width. A only |
| `rimWidth`, `rimOpacity` | Inner highlight band — the reference's `erode` pass |
| `rimOffsetY`, `rimSecondaryOpacity` | Its offset twin — the reference's `feOffset` pass |
| `shadowRadius`, `shadowOpacity`, `shadowOffsetY` | Outer shadow — the reference's `dilate` pass |
| `fill` | `nil` resolves to the theme's `trackActive` |
| `wobble`, `wobbleSpeed` | Optional liquid shimmer displacing the distance field. Off by default; one `sin` per shape |

**`GlitchGooField`:** `trigger` (`.focus` / `.nonEmpty` / `.always`), `detachDistance`,
`buttonDiameter`, `capsuleContraction`, `submitImage`, and travel taken from the motion tokens
unless overridden.

**Radial menu:** the shared set, plus `bondsTrigger` — whether petals bond to the trigger or only to
one another. Radii, stagger and timing come from the existing `PathMenuStyle`.

## Demo

- **`Demo/GooLabView.swift`** — a fourth tab beside Playground, Gallery and Motion Lab. Both effects
  under one live parameter panel, the renderer A/B picker, and presets. The panel is built from the
  system's own sliders and pickers, so the lab exercises the controls while tuning them.
- **`Demo/GalleryView.swift`** — a "Gooey" group showing `GlitchGooField` in its states, and a
  Surface picker added to the existing "Radial menu" group so goo appears in the catalogue in
  context rather than only in the lab.
- **`App/GlitchDesignSystemApp.swift`** — registers the tab.

## Testing

Following the existing rule that value and geometry maths is pure and unit-tested, `Tests/GlitchMathTests/`
gains coverage for:

- `smin` — commutativity, that it agrees with `min` as k approaches zero, and that it never exceeds
  `min`.
- `GooShape` packing — round-trips, and stays within the kernel's declared capacity.
- The master-clock derivation — per-petal progress against hand-computed values at boundaries, with
  and without stagger. This is where a defect would silently desync blob from icon, which is
  precisely the class of bug a screenshot does not catch.

Rendering itself is verified by running the app, not by assertion.

## Constraints carried from the existing plan

- Swift 5 language mode; public types prefixed `Glitch`; no ad-hoc animations outside the motion
  tokens; no `#if os(...)` in control bodies.
- Files under `Glitch Design System/` are compiled by the synchronized group — **never edit
  `project.pbxproj`.**
- Build: `xcodebuild -scheme "Glitch Design System" -destination 'platform=macOS' build`
- Test: `swift test`
- Both must pass: the package and the app compile the same files by different routes, which is
  exactly what the shader packaging question turns on.

## Risks

| Risk | Handling |
|---|---|
| Build-tool plugin does not work cleanly | Spike it first, before any control work. Fall back to app-target-only with renderer B for package consumers |
| Metal shaders do not render in Xcode's preview canvas in all configurations | `#Preview`s may show `.plain`. The simulator and the running app are the check; note it where the previews live |
| Two code paths through `PathMenuPetal` | Confined to the gooey surface; solid and glass are untouched. Reunify only if the gooey path proves itself |
| Shader argument limits | Shapes travel as one packed `floatArray` with a declared capacity, tested against it |
| Colour fidelity — shader output is premultiplied | Resolve palette colours explicitly at the boundary rather than trusting the implicit conversion |

## Out of scope

- Gooifying arbitrary child views. Renderer B could support it; nothing here requires it.
- The reference's third demo (the draggable avatar cluster).
- Replacing or restyling `GlitchTextField` and `GlitchSearchField`.
