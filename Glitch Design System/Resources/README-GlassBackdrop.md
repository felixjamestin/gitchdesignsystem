# Glass backdrop photograph

Drop a photograph named `GlassBackdrop.jpg` (or `.png` / `.jpeg`) into this
folder and the Glass theme will use it as its page background.

The folder is inside the target's file-system-synchronized group, so the file
is bundled automatically — no Xcode step, no asset catalog. An asset catalog
was tried first and rejected: compiling one requires an installed simulator
runtime matching the SDK, which broke the iOS build on a machine that has the
SDK but not the runtime.

With no photograph present, `GlitchBackdrop` falls back to a generated mesh
gradient in the same palette, so the Glass theme always has something worth
refracting.
