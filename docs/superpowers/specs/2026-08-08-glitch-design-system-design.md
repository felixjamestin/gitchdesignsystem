# Glitch Design System — Design

**Date:** 2026-08-08
**Status:** Approved
**Scope:** A custom SwiftUI control library for macOS and iOS, plus a demo app for exercising it.

## Goal

Build a set of UI controls inspired by two references: a dense creative-tool parameter panel, and a
refined macOS inspector. Both share one idea worth stealing — **the label, the fill, and the value
occupy a single row**, so a slider doubles as its own label and no vertical space is wasted on
captions.

**Revised 2026-08-08 (second pass).** The system now matches a third reference — the `dialkit`
panel at `experiments.thisiswhitespace.com/dot-sphere-card` — in both mechanics and appearance, at
the user's direction. That supersedes the original "refined, with grit" direction:

- **No chromatic accent.** Every surface is a white alpha over the panel; activity is expressed as
  *more white*, never as a different hue. An accent remains available per subtree via
  `.glitchTheme(accent:)` but is neutral by default.
- **Labels are sentence case**, not uppercase, at the same 13pt medium as the value beside them.
- **36pt rows, 8pt radius, `#212121` panel at 14pt** — the reference's exact geometry.
- **Booleans are Off/On segmented pairs**, not switches. `GlitchSwitch` remains for cases that
  genuinely want a sliding switch.

Three things the reference lacks are kept as deliberate additions, because removing them would
make the controls strictly worse: **keyboard operation, VoiceOver support, and iOS haptics.**

**Third pass — themes and notch snapping.**

- **`GlitchThemeStyle`** adds a style dimension orthogonal to density: `.glitch` (the above),
  `.engineering` (Teenage Engineering — light chassis, black legends, one hot orange, tight radii,
  uppercase labels), and `.brutalist` (no radii, 2pt borders, monospaced uppercase). A style
  changes colour, radius, border weight and typography — **never behaviour**. Any style works at
  any density, in either colour scheme.
- **`GlitchNotchSnapping`** controls whether dragging sticks to the notches: `.off` (the
  reference's behaviour, and the default), `.magnetic` (notches attract from within 3.5% of the
  range), `.locked` (every drag lands on a notch). The notches are the drawn hashmarks, so what
  snaps is always something visible.
- The platform focus ring is suppressed system-wide inside `glitchFocusRing`, so no control shows
  a blue halo in a system that contains no blue.

**Fourth pass — glass, bounce, stagger.**

- **No focus outline at all**, ours included. Focus now resolves to the same surface lift as hover
  (`ControlState.trackFill`), and a focused slider counts as active — so tabbing to one reveals its
  notches and handle exactly as pointing at it does. Keyboard users keep an indicator; nothing gets
  a box drawn around it.
- **`.liquidGlass` style**, built on a new `GlitchSurface` axis. Surfaces are the only thing a
  style can change *structurally* rather than by token: `.solid` fills, `.glass` applies the
  platform material tinted by the same colour a solid style would have filled with. Radii open to
  half the row height, since glass with tight corners reads as a chip of it.
- **Magnetic pull is 1%** of the range, down from 3.5% — a reward for aiming at a notch rather than
  a force acting on values set deliberately between them.
- **Bounce.** Every spring token gains overshoot (`glide` 0.42/0.34, `pop` 0.28/0.30, `drift`
  0.40/0.28, `snap` 0.22/0.22), departing from the reference's near-critical damping, which reads
  as struck rather than sprung. Dragging is still literal — rule 7 is unaffected.
- **Staggered disclosure.** `GlitchSection` reaches its children individually via
  `Group(subviews:)` and gives each a delayed transition: opening unrolls top-down on `drift`,
  closing rolls up bottom-first on the quicker `snap`. `GlitchMotion.staggerDelay` is 35ms, and
  zero under Reduce Motion — which collapses a stagger into one simultaneous change.

**Fifth pass — game feel.**

- **`GlitchGlassVariant`** selects `.regular` or `.clear` glass, passed as `.glitchTheme(_:glass:)`
  and carried in `GlitchSurface.glass(_:)`.
- **Magnetic pull is 2%** of the range.
- **The engineering style was rebuilt.** The first attempt was the default style in beige. What
  reads as Teenage Engineering is the *construction*, not the palette: an unpainted chassis with
  parts let into it (a barely-recessed track), scales printed onto the surface rather than summoned
  by touching it (`hashmarksAlwaysVisible`), legends engraved small and spaced wide (9pt, 1.6
  tracking, bold, uppercase), colour only where something is live (full-strength orange fill), and
  selection as a printed switch — solid black with a knocked-out legend, via the new
  `selectionFill` / `onSelection` palette tokens.
- **`glitchDelight`** gates a game-feel layer, on by default, separable because effects tuned for
  delight are exactly the ones that grate on the hundredth use. **It never changes which values a
  control can reach.** It adds: hit-stop at the limits (55ms, borrowed from fighting games), a
  fading ghost of where a value jumped from, velocity-proportional inertia in the fill (≤2.5pt),
  notch proximity lighting (5%, wider than the 2% pull so the grab is announced), and panel-level
  cascade on first appearance. Tuning constants live together in `GlitchDelightTuning`.

Controls must feel responsive and deliberate, not merely animated. Motion follows a fixed set of
rules (Section 4) rather than per-control improvisation.

## Non-goals

- No Swift Package. The system lives in the app target; extraction later is a folder move.
- No theming engine beyond a single overridable accent color and light/dark palettes.
- No snapshot tests of animation. Feel is verified by hand in the Gallery, not asserted.
- No localization or RTL work in this pass.
- No new controls beyond the roster in Section 5.

## 1. Platform and language baseline

The project targets **iOS 27.0 and macOS 27.0** (`SUPPORTED_PLATFORMS` also lists visionOS; we do
not target it, and will not add visionOS-specific code, but must not write anything that fails to
compile there).

**The installed SDK is 26.5**, below the configured deployment target. Xcode emits a warning and
builds successfully, but the effective API ceiling is **26.x** — code must not use APIs introduced
in 27. If the toolchain is later updated, this constraint can be relaxed.

The Swift language mode stays at **5.0**, as currently configured. Migrating to Swift 6 strict
concurrency is unrelated to this work and would add churn.

## 2. Architecture

Everything lives inside the existing app target.

```
Glitch Design System/
  App/
    GlitchDesignSystemApp.swift    // @main; the existing ContentView.swift is deleted, its
                                   // `MyApp` entry point moving here
    RootView.swift                 // 3-tab shell: Playground · Gallery · Motion Lab
  Glitch/
    Tokens/
      GlitchColor.swift            // semantic palette, light + dark
      GlitchMetrics.swift          // radii, row heights, spacing, stroke widths, per density
      GlitchType.swift             // label / value / mono text styles
      GlitchTheme.swift            // Environment-injected theme + accent override
    Motion/
      GlitchMotion.swift           // the four named springs
      MotionScale.swift            // global time multiplier (drives the Motion Lab)
      Pressable.swift              // press-scale + state tracking modifier
      Hoverable.swift              // cross-platform hover modifier
      Haptics.swift                // iOS haptics; compiles to no-op elsewhere
    Controls/                      // one file per control, 15 files
    Chrome/
      GlitchPanel.swift
      GlitchSection.swift          // collapsible, chevron per reference image 2
      GlitchDivider.swift
  Demo/
    PlaygroundView.swift
    GlitchCanvas.swift             // the animated thing the controls actually drive
    GalleryView.swift
    MotionLabView.swift
```

Public types carry a `Glitch` prefix (`GlitchSlider`, `GlitchToggle`) — greppable, and no collision
with SwiftUI's own `Slider` / `Toggle` / `Stepper`.

### Controls are drawn, not restyled

Controls are composed from shapes, gestures, and layout primitives. They do **not** wrap and
restyle native `Slider`, `Toggle`, `Picker`, or `Stepper`. Restyled native controls are the standard
failure mode for cross-platform SwiftUI design systems: AppKit appearance bleeds through on macOS,
the two platforms diverge in ways the style protocols cannot reach, and control metrics stop being
ours to set.

**One exception:** `GlitchTextField` and `GlitchSearchField` wrap a real `TextField` with
`.textFieldStyle(.plain)` inside custom chrome. Reimplementing text selection, IME, autocorrect, and
system keyboard behavior would be strictly worse than the platform's.

Because controls are custom-drawn, each one must declare explicit accessibility traits, values, and
adjustable actions. A control VoiceOver cannot operate is not finished.

## 3. One codebase, two platforms

No `#if os(...)` branches inside control bodies. Platform difference is absorbed by three
mechanisms, each defined once:

**Density.** A `GlitchDensity` environment value with two cases — `.compact` (default on macOS,
~28pt rows) and `.comfortable` (default on iOS, ~44pt rows). `GlitchMetrics` resolves every
dimension through it. This is the single mechanism that lets a Mac inspector survive a thumb: same
view code, different numbers. Density is overridable per subtree so the Gallery can show both.

**Hover.** A `.glitchHover { isHovering in ... }` modifier resolving to real hover on macOS and
iPad pointer, and to nothing on iPhone. Hover-revealed affordances (reference image 2's `⊗` reset
button) therefore **enhance and never gate**: anything reachable by hover must also be reachable on
touch, via long-press or a persistently visible control.

**Input parity.** Every control accepts drag on all platforms. Where a keyboard or scroll device
exists, sliders and drag-fields additionally accept scroll-wheel and arrow keys. Nothing is
pointer-only or keyboard-only.

## 4. Motion

Ten rules, applied to every control. These are the specification, not suggestions.

1. **Interruptible always.** Springs only. No `.linear`, no fixed duration that cannot be redirected
   mid-flight.
2. **Respond on press.** Visual acknowledgment within ~50ms of touch-down; the value commits on
   release.
3. **Animate only what moved.** Fill, knob, and checkmark animate. Layout never shifts — no reflow
   jitter, ever.
4. **Spatial continuity.** Popovers and menus scale from their anchor point, not from center.
5. **Duration follows distance.** A 16pt knob travel resolves faster than a 200pt popover expansion.
6. **The cursor is state.** Hover reveals affordances; drag-fields swap to a horizontal-resize
   cursor.
7. **Never animate under the finger.** While dragging, the fill tracks the input 1:1 with animation
   explicitly disabled. Springs apply on release only. Animating during a drag reads as lag.
8. **Limits are physical.** Dragging past min/max meets rubber-band resistance and springs back on
   release.
9. **Discrete events get texture.** Crossing a step fires a haptic tick and a subtle value-label pop.
10. **Reduce Motion is real.** A single environment read collapses all positional springs to
    opacity or instant changes.

### Motion tokens

Five tokens, defined once in `GlitchMotion`, carried over from the reference's own spring
configurations. **No control may declare an ad-hoc animation.**

| Token | Value | Used for |
|---|---|---|
| `snap` | spring, duration 0.20, bounce 0.15 | segmented pill travel |
| `glide` | spring, mass 0.8 / stiffness 300 / damping 25 | a value settling to a clicked position |
| `pop` | spring, duration 0.25, bounce 0.15 | the slider handle revealing itself |
| `drift` | spring, duration 0.35, bounce 0.15 | overscroll release, section disclosure |
| `tint` | ease-out 0.15s | colour and opacity only — no momentum to preserve |

Every token reads a `MotionScale` environment multiplier (default 1.0). The Motion Lab sets it as
low as 0.1× to inspect easing — with no special-casing inside any control.

## 5. Controls

### The hero: `GlitchSlider`

A 36pt rounded-rect track. The label sits inside at the left, the monospaced value inside at the
right, and a white 11% fill grows from the left edge — brightening to 15% while the row is engaged.

Behavior, matching the reference exactly:

- **Pressing does not move the value.** Touch-down only makes the row active. A slider that jumps
  on press cannot be clicked to focus, cannot be pressed and reconsidered, and turns every
  mis-aimed click into an edit. Movement past **3pt** starts a drag.
- **A drag is taken literally** — continuous absolute tracking with no animation between the
  pointer and the fill.
- **A click is helped onto a tick.** On release without dragging, the value animates (`glide`) to
  the clicked position, snapped to the nearest 10% tick if within **3.125%** of one — or to the
  nearest step when the range has ten or fewer steps.
- **Hashmarks** mark exactly those ticks: one per step for coarse ranges, otherwise nine at 10%.
  Invisible at rest, white 15% while active.
- **The handle is hidden at rest.** 3×20pt, `scaleX 0.25 → 1` on activation (`pop`), opacity 0 →
  0.5, → 0.9 while dragging, → 0.1 when it would collide with the label or value text.
- **The track itself stretches past its limits** — not its contents sliding within it. Resistance
  begins only 32pt beyond the edge, follows `8·√(distance/200)`, caps at 8pt, and releases with
  `drift`.
- **The value is editable.** Resting on the row for 800ms underlines it; click to type, Return
  commits, Escape cancels.

Beyond the reference: ← / → adjust by one step and ⇧← / ⇧→ by ten, scroll wheel adjusts under the
pointer, and a haptic ticks on each step crossed.

### Full roster

**Core:** `GlitchSlider`, `GlitchTextField`, `GlitchSelect`, `GlitchRadioGroup`, `GlitchToggle`,
`GlitchButton` (primary / secondary / ghost), `GlitchSegmented`, `GlitchStepper`, `GlitchSwatch`,
`GlitchCheckbox`.

**Extras:** `GlitchDragField` (horizontal scrub to change, click to type), `GlitchXYPad`,
`GlitchDial`, `GlitchSearchField`, `GlitchChips`.

**Chrome:** `GlitchPanel`, collapsible `GlitchSection`, `GlitchDivider`.

Notes on two of these:

- `GlitchSelect` uses a **custom anchored popover on both platforms** rather than SwiftUI `Menu`,
  because `Menu` renders as a native system menu on macOS and an action sheet or inline picker on
  iOS — visually unrelated to each other and to this system. The custom popover must therefore
  handle its own keyboard navigation (↑/↓ to move, ↩ to select, ⎋ to dismiss) and dismissal on
  outside tap.
- `GlitchSegmented` moves its selection indicator with a matched-geometry effect so the indicator
  slides between options rather than cross-fading.

### Shared state model

Every control renders from one shared `ControlState`. It is a **struct of independent flags**, not
an enum: `isHovering`, `isPressed`, `isFocused`, `isDragging`, `isDisabled`, `isErrored`. These
states co-occur in practice — a control can be focused *and* hovered *and* disabled — and an enum
would force a false precedence at the point of assignment rather than at the point of rendering.
Precedence is resolved once, in the shared styling helper that maps a `ControlState` to fill,
stroke, and scale, so controls do not each invent their own notion of "pressed".

## 6. Correctness

The failure modes for a control library are specific and known. Each is guarded explicitly:

- **Degenerate ranges.** `lowerBound == upperBound` must not divide by zero — the classic custom
  slider crash. Such a range renders a full-width, non-interactive fill.
- **Zero-size layouts.** Drag math must not produce NaN when the available width is 0.
- **Unclamped values.** Every value is clamped to its range on both input and binding write-back.
- **Empty option lists.** `GlitchSelect`, `GlitchRadioGroup`, `GlitchSegmented`, and `GlitchChips`
  must render sensibly with zero options rather than crashing or displaying garbage.
- **Text input.** Fields validate on commit and surface an error message that animates in below the
  field. A shake animation is available but off by default.

## 7. Testing

The split is honest:

- **Unit-tested with Swift Testing** — the pure value and geometry math, extracted out of the views
  so it is testable at all: value↔position mapping, clamping, step snapping, the rubber-band curve,
  drag-field string parsing, and dial angle↔value wrapping including the wrap discontinuity.
- **Verified by hand** — appearance and feel, in the Gallery and in SwiftUI Previews. Snapshot tests
  of spring animation would assert implementation details, not correctness.

Implementation follows the TDD skill: the extractable math gets a failing test before the code.

## 8. Demo app

Three tabs in `RootView`.

**Playground** — a real inspector panel driving an animated canvas. Moving a slider visibly changes
the rendering. This is the primary feel-test: controls doing actual work, not sitting in a catalog.

**Gallery** — every control in every state (idle, hover, focus, disabled, error), grouped by type,
with a density toggle so both `.compact` and `.comfortable` can be compared side by side.

**Motion Lab** — the `MotionScale` multiplier exposed as a control, down to 0.1×, so animations can
be slowed and inspected. Also exposes the Reduce Motion override for verifying rule 10.

## 9. Definition of done

- All 18 controls and chrome components implemented, each with accessibility traits and values.
- All ten motion rules observably held; no ad-hoc animations outside `GlitchMotion`.
- Both platforms build and run; both densities usable.
- Unit tests pass for all extracted value and geometry math.
- The demo app runs on macOS and iOS with all three tabs functional.
