# Glitch

A SwiftUI control set for macOS and iOS. Drawn from primitives rather than
restyled from system controls, so a slider looks and behaves identically on
both platforms — and keeps its keyboard, VoiceOver and haptic support, which
the reference panels it borrows from do not have.

Requires **iOS 26 / macOS 26** (Liquid Glass, `Group(subviews:)`, `@Entry`).

---

## Adding it to a project

**Local, while you're iterating on both:** in Xcode, *File → Add Package
Dependencies… → Add Local…* and choose this folder. Then add the `Glitch`
library to your target.

**By URL, once it's pushed:**

```swift
.package(url: "https://github.com/you/glitch-design-system", from: "1.0.0")
```

```swift
.target(name: "YourApp", dependencies: [.product(name: "Glitch", package: "glitch-design-system")])
```

The package vends the same files the demo app compiles — there is no mirrored
copy to drift out of sync.

---

## Quick start

Install a theme once, at the root. Controls read everything else from there.

```swift
import SwiftUI
import Glitch

struct ContentView: View {
    @State private var flow = 73.0
    @State private var loop = true

    var body: some View {
        GlitchPanel {
            GlitchSection("Parameters") {
                GlitchSlider("Flow", value: $flow)
                GlitchToggle("Loop", isOn: $loop)
            }
        }
        .glitchTheme()          // colours, metrics, typography
        .glitchMotion()         // animation tokens
        .glitchSound()          // audio feedback
    }
}
```

Only `.glitchTheme()` is required. Without the other two you get the default
motion and no sound.

---

## Sound

Sound is **global** — there is one speaker, so it is a shared setting rather
than an environment value. Applying it anywhere applies it everywhere.

```swift
ContentView()
    .glitchTheme()
    .glitchSound(isEnabled: settings.soundOn, volume: settings.volume)
```

- `isEnabled` — whether the controls make any sound. Default `true`.
- `volume` — `0` to `1`. Default `0.6`, deliberately low: this is punctuation,
  not content.

Wire it to your own controls and it updates live:

```swift
struct AudioSettings: View {
    @State private var soundOn = true
    @State private var volume = 0.6

    var body: some View {
        GlitchPanel {
            GlitchToggle("Sound", isOn: $soundOn)
            GlitchSlider("Volume", value: $volume, in: 0...1, step: 0.05)
            GlitchSoundGrille(isOn: soundOn, volume: volume, in: 0...1)
        }
        .glitchSound(isEnabled: soundOn, volume: volume)
    }
}
```

You can also set it directly, outside a view — useful from a settings store or
an app delegate:

```swift
GlitchSound.isEnabled = false
GlitchSound.volume = 0.35
```

### Three voices

Every control speaks with the same three, so the same event always sounds the
same wherever it happens:

| Voice | Used for |
|---|---|
| `tick` | traversal — a notch crossed, a segment moved, a step taken |
| `commit` | something landed — a button fired, a value arrived, a menu chose |
| `reject` | something refused — a limit hit, a value out of range |

Sound mixes with other audio and obeys the ring switch on iOS.

### Sound and the delight switch

`.glitchDelight(false)` silences the system, since sound is one of the
embellishments. Turning delight back on restores whatever sound preference you
set rather than forcing sound on — **delight can quieten the system, it cannot
make it speak.**

---

## Theming

Four styles. A style changes colour, radius, border weight, typography and
material — never behaviour.

```swift
ContentView().glitchTheme(.engineering)
```

| Style | Character |
|---|---|
| `.glitch` | Default. Neutral white alphas over near-black. |
| `.engineering` | Instrument panel: light chassis, printed scales, one hot orange. |
| `.film` | Near-total absence. No containers, no borders, generous space. |
| `.liquidGlass` | The platform glass material, tinted by the same tokens. |

Glass takes a variant:

```swift
ContentView().glitchTheme(.liquidGlass, glass: .clear)   // or .regular
```

Density is separate, and any style works at any density:

```swift
ContentView().glitchTheme(.film, density: .comfortable)  // or .compact
```

`.compact` is the pointer default (36pt rows), `.comfortable` the touch default
(48pt). Both are always available.

An accent can be supplied per subtree — the system is otherwise monochrome:

```swift
ContentView().glitchTheme(accent: .orange)
```

Light and dark come from the environment, so `.preferredColorScheme` or the
system setting both work.

---

## Motion

Five tokens, and controls may not declare their own animation:

| Token | Used for |
|---|---|
| `snap` | state changing in place — a knob, a checkmark |
| `glide` | a value settling where you pointed |
| `pop` | something revealing itself |
| `drift` | disclosure, ambient |
| `travel` | whole views moving |

Scale them globally, which is how the demo's Motion Lab slows everything to
inspect it:

```swift
ContentView().glitchMotion(scale: 0.25)          // quarter speed
ContentView().glitchMotion(reduceMotion: true)   // force reduced motion
```

The system Reduce Motion setting is always honoured; the parameter can only
add the behaviour, never remove it.

---

## Game feel

A layer of effects borrowed from game design, on by default:

```swift
ContentView().glitchDelight(false)
```

It adds hit-stop at limits, a fading ghost of where a value jumped from,
velocity-proportional inertia in a slider's fill, notch proximity lighting,
staggered panel disclosure, squash on landing, and sound.

**It never changes which values a control can reach.** Every value reachable
with it on is reachable with it off; the maths is identical. It's separable
because effects tuned for delight are exactly the ones that grate on the
hundredth use.

---

## Controls

### Slider

```swift
GlitchSlider("Flow", value: $flow)
GlitchSlider("Vignette", value: $v, in: 0...1, step: 0.01)
GlitchSlider("Gain", value: $gain, in: 0...100, step: 1, notches: .magnetic)
```

The whole track is the handle — pressing anywhere and dragging grabs it, and
a *click* (no drag) animates to that position. `notches:` controls whether
dragging sticks to the drawn hashmarks: `.off` (default), `.magnetic` (they
attract from within 2% of the range), `.locked` (every drag lands on one).

Hover a row for 800ms and the value offers itself for typing. Arrow keys
adjust; ⇧ multiplies by ten.

### Numbers

```swift
GlitchDragField("X", value: $x, in: -500...500)   // scrub sideways, click to type
GlitchStepper("Copies", value: $count, in: 1...64)
```

### Text

```swift
GlitchTextField("Name", text: $name, placeholder: "Your name")
GlitchTextField("Email", text: $email, error: valid ? nil : "Needs an @")
GlitchSearchField(text: $query)
```

Passing `error:` reserves the message's row, so it fades into space already
allotted rather than shoving everything below it down.

### Booleans and choices

```swift
GlitchToggle("Loop", isOn: $loop)            // Off/On pair
GlitchSwitch("Legacy", isOn: $loop)          // sliding switch, if you want one
GlitchCheckbox("Show trails", isOn: $trails)

GlitchSegmented("Blend", selection: $blend, options: [
    GlitchOption("Add", value: "add"),
    GlitchOption("Screen", value: "screen"),
])

GlitchRadioGroup("Mode", selection: $mode, options: GlitchOption.list(["Flow", "Echo"]))
GlitchSelect("Easing", selection: $easing, options: GlitchOption.list(["Linear", "Spring"]))
```

`GlitchOption` is generic over any `Hashable`, so selections can be enums:

```swift
GlitchSegmented("Density", selection: $density,
    options: GlitchDensity.allCases.map { GlitchOption($0.title, value: $0) })
```

### Buttons

```swift
GlitchButton("Record", systemImage: "record.circle", style: .primary) { start() }
GlitchButton("Cancel", style: .ghost) { dismiss() }
```

### Two dimensional

```swift
GlitchXYPad("Displacement", x: $x, y: $y)
GlitchDial("Rotation", value: $angle, in: -180...180)
GlitchDial("Depth", value: $depth, style: .halo)
```

Dials take a face — `.arc`, `.printed`, `.minimal`, `.halo`. Each theme picks
one by default. Drag to turn; **tap a point on the dial** to send the mark
there.

### Colour and tags

```swift
GlitchSwatchRow(swatches: [(.orange, "Ember"), (.teal, "Mint")], selectedIndex: $i)
GlitchChips("Tags", items: $tags)
```

### Readout

```swift
GlitchSoundGrille(isOn: soundOn, volume: volume)
GlitchSoundGrille("Output", isOn: soundOn, volume: volume, style: .matrix)
```

Display only — no gesture, no focus, no VoiceOver action. Forms: `.perforated`,
`.matrix`, `.dotted`, `.rings`, one per theme by default.

### Radial menu

```swift
GlitchPathMenu(items: [
    PathMenuItem(title: "Flow", systemImage: "wind"),
    PathMenuItem(title: "Echo", systemImage: "waveform.path.ecg"),
]) { item in
    perform(item)
}
```

Press the trigger and drag straight onto a petal to choose in one gesture.

### Chrome

```swift
GlitchPanel {
    GlitchSection("Rotation") {
        GlitchSlider("X", value: $x, in: -180...180)
        GlitchSlider("Y", value: $y, in: -180...180)
    }
    GlitchDivider()
    GlitchSection("Options", initiallyExpanded: false) {
        GlitchToggle("Loop", isOn: $loop)
    }
}

GlitchTabBar(selection: $tab, items: [
    GlitchTabItem(id: 0, title: "Edit", systemImage: "slider.horizontal.3"),
    GlitchTabItem(id: 1, title: "Preview", systemImage: "eye"),
])
```

Sections unroll their rows with a stagger on every expand.

---

## Composing a screen

```swift
struct Inspector: View {
    @State private var style = GlitchThemeStyle.glitch
    @State private var soundOn = true

    var body: some View {
        ScrollView {
            GlitchPanel {
                GlitchSection("Appearance") {
                    GlitchSegmented("Theme", selection: $style,
                        options: GlitchThemeStyle.allCases.map {
                            GlitchOption($0.title, value: $0)
                        })
                    GlitchToggle("Sound", isOn: $soundOn)
                }
            }
            .padding(16)
        }
        .background(GlitchPalette.resolve(.dark).background)
        .glitchTheme(style)
        .glitchMotion()
        .glitchSound(isEnabled: soundOn)
    }
}
```

---

## Notes

- **Disabling** works the standard way: `.disabled(true)` on any control.
- **The glass backdrop** in the demo looks for
  `Resources/GlassBackdrop.jpg` and falls back to a generated gradient. That's
  demo-side; in your own app, put whatever you like behind a glass theme.
- **Value and geometry maths** (`GlitchValueMath`, `GlitchAngleMath`,
  `GlitchNumberParsing`) are public and unit-tested, if you need to build a
  control of your own that behaves consistently with these.
