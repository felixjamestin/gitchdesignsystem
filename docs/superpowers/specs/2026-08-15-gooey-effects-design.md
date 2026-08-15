# Gooey effects: GlitchGooField and the gooey path menu

*2026-08-15 — approved design*

Two liquid "goo" effects, modelled on gooey.jakubantalik.com, rendered with a
Metal SDF shader through SwiftUI's `Shader` API:

1. **GlitchGooField** — a capsule text field whose submit button buds off the
   right end when focused, connected by a stretching liquid neck, and merges
   back on blur.
2. **A `.gooey` variant of `GlitchPathMenu`** — petals that stay joined to the
   trigger by liquid necks while they fan out.

Both are capsule-plus-circles, so they share one renderer.

## Why SDF over blur + threshold

The reference implements goo the classic web way: Gaussian-blur solid shapes,
then slam alpha contrast so overlapping halos fuse into necks. Ported literally
(SwiftUI `Canvas` with `.blur` + `.alphaThreshold` filters) that costs an
offscreen layer and two blur passes per animated frame, and the edge is soft.

An SDF shader computes the same silhouette analytically: capsule SDF, circle
SDFs, joined by a polynomial smooth-min. One pass, no intermediate textures, a
few dozen ALU ops per pixel over only the control's footprint; cost independent
of "blur radius". Edges antialias through `fwidth`, so they stay crisp at any
display scale. The smooth-min `k` *is* the gooeyness dial — a more designer-
honest parameter than blur × contrast.

## The goo core — `Glitch/Goo/`

- **`Goo.metal`** — one `[[stitchable]]` colorEffect function. Arguments: a
  float array of blobs (capsule: center, half-length, radius; circles: center,
  radius), smooth-min `k`, edge softness, fill color. Returns fill with
  AA alpha from `smoothstep(±fwidth)` on the joined distance.
- **`GooSurface.swift`** — internal SwiftUI view + `Animatable` modifier owning
  the blob list. `animatableData` carries the blob offsets, so ordinary SwiftUI
  springs animate the goo; per-frame work is a uniform update on a
  `Color.clear` rect padded enough to contain the necks. No `TimelineView`, no
  layout per frame.
- **Shader lookup helper** — the `.metal` file is compiled by SPM into the
  module's metallib *and* by Xcode into the app's default library (same file,
  file-system-synchronized group). A helper tries
  `ShaderLibrary.bundle(.module)` and falls back to `ShaderLibrary.default`.

The core stays internal to the module until a third consumer appears.

## GlitchGooField

A sibling of `GlitchTextField`, same philosophy: wrap the native `TextField`,
replace only its appearance. Anatomy:

- A goo underlay: capsule blob for the field, circle blob for the submit
  button.
- Focus detaches the circle to the right by `detachDistance` on the theme's
  travel spring; blur merges it back. The neck stretches and snaps as part of
  the SDF union — no separate animation.
- The submit button shows an arrow icon, hit-testable only while detached;
  activating it (or return) fires `onSubmit`.

Public parameters: `goo` (smooth-min k), `detachDistance`, `buttonDiameter`,
spring `response`/`dampingRatio` (defaulting to the motion tokens), capsule
height (from density metrics), tint (from palette, overridable). Placeholder,
binding, and accessibility mirror `GlitchTextField`.

## Gooey path menu

`GlitchPathMenu` gains a `.gooey` variant. Liquid Glass petals cannot merge
into one another, so gooey implies a solid shader-drawn fill; the variant sits
alongside the existing surface treatment and documents that constraint.

Rendering follows the reference's structure:

- The goo underlay draws the trigger disc and every petal disc as blobs.
- Petal views render only their icons; the discs they normally draw are
  suppressed in this variant.
- The underlay's blob offsets animate on the same spring tokens and stagger
  the petals already use, so discs and icons travel together.

Drag-to-select, hover highlight, haptics, sounds, and the delight flourishes
are untouched. Highlight grows the corresponding blob's radius (a value the
shader already receives per blob) and restyles the icon, mirroring the scale
bump the solid petal performs today; the fill stays a single color.

## Demo — Goo Lab

A new `GooLabView` tab in the demo app, laid out like `PlaygroundView` (canvas
plus `GlitchPanel`, wide/narrow adaptive). The canvas hosts both effects; the
panel drives them with the system's own controls:

- Sliders: goo, edge softness, detach distance, petal radius, spring response,
  damping, stagger.
- Stepper: petal count.
- Swatches: tint.
- Toggle: gooey on/off for the menu, to compare against the standard variant.

## Testing

The pure-geometry parts — blob layout, capsule/circle SDF and smooth-min math
mirrored in Swift, detach interpolation — live under the `Glitch/Math`
conventions and are unit-tested in `GlitchMathTests`. The shader is verified
visually in the Goo Lab; no snapshot infrastructure exists and none is added.

## Out of scope

Arbitrary blob shapes beyond capsule + circles; goo between unrelated
controls; a public goo API beyond these two components.
