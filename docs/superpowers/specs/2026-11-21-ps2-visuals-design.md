# PS2-era visuals (hi-res 2D) — design

## Intent
Move the look from PS1 (384×216, 16-colour dithered sprites) to early-2000s PS2 2D fighters
(Guilty Gear XX, KOF 2002, SNK vs Capcom). The user picked hi-res 2D over 3D. Art stays
generated in code (user's earlier choice). Gameplay just reached a fully working state; this must not
disturb it.

## Goals
- Fighters: 2× texel density (224×224 cells, figure ~200px tall in texels), 256-colour palette per
  sheet, smooth multi-step gradient shading (no Bayer dither), soft anti-aliased 2px outline,
  rim light on the side away from the key light.
- Stages: 2× texel density (1536×432 layers), truecolour/smooth gradients, atmospheric
  depth (haze toward the horizon), light glow (forge mouths, moon), more parallax layers where
  cheap (stage1 gets sky / ridge / foreground split).
- Effects: additive-blend hit sparks with a glow halo and short streak lines; block sparks in blue;
  a brief white flash on heavy hits (damage >= `CombatPresentation.heavyDamageThreshold`)
  applied to the struck fighter's sprite only (colour-blend, ~3 ticks), never full-screen
  (photosensitivity); glow comes from pre-baked additive halo sprites, not a full-screen filter.
- HUD: gradient-filled bars with bevel highlight, crisper text (rendered at 2× density).
- Filtering: bilinear (`.linear`) for sprites and stages — the soft PS2 look — instead of `.nearest`.

## Non-goals
- No 3D, no SceneKit, no new renderer.
- No change to sim, hitboxes, frame data, golden hashes, or menu flow.
- No new animation states (frame names stay the SpriteSelection contract); more in-between
  frames only where the generator can add them under existing names.

## Anti-goals (failure even if it "works")
- Any gameplay/golden-hash change, or a frame-rate drop below 60 fps on the dev Mac.
- Blurry mush: at 1× window scale sprites must still read; bilinear must not smear outlines.
- Losing the readable silhouettes / colour identity of the four fighters.

## Constraints
- Logical scene stays 384×216 (`SceneConstants`): WorldToScene, FightCamera, HUDLayout, collision
  and all existing tests keep their numbers. Hi-res comes from texel density, not new coordinates.
- `sheet.json` is a top-level array today; the loader accepts either that or an object
  `{"texelScale": 2, "frames": [...]}` (default 1), so greybox and fixtures load unchanged. Frame rects stay in sheet
  pixels; `SpriteAtlas` sizes nodes at `w / texelScale`, `h / texelScale`, so anchors keep working.
  Stage layers likewise carry a texel scale (StageArt). greybox stays 1× and must still load.
- Generators remain stdlib-only Python, deterministic (same output byte-for-byte on re-run).
- Bundle size: keep total Content PNGs under ~8 MB.
- CI's older Xcode: avoid ambiguous CGFloat/Double maths (see EffectNodes fix).

## Approaches considered
1. **Hi-res 2D via texel density (chosen).** Same pipeline and coordinates; art and render polish
   only. Low risk to gameplay.
2. Raise the logical resolution to 768×432. Same visual result, but every coordinate constant,
   camera clamp, HUD frame and test number changes — risk for no visual gain. Rejected.
3. Full 3D (Tekken 4 style). Rejected by the user: renderer rewrite, high risk.

## Decided
- Hi-res 2D, generated in code, bilinear filtering, 2× texel density, logical 384×216 kept.

## Builder's calls (made during review)
- Baseline: branch from the PR #26 head (`playtest/20261121-focus-guard`); stash@{0} stays
  untouched and must still apply cleanly at the end (re-run the worktree trial-apply).
- Rim light is baked into the sheet and flips with the sprite, like PS2-era 2D fighters did. No
  mirrored frame sets.
- Target setup: dev Mac Retina display at 2× window scale and fullscreen; 60 fps must hold in both.
  Textures use mipmaps (`usesMipmaps`) so 1× windows don't shimmer.

## Left to the builder
- Exact palettes, gradient step counts, rim-light strength, halo sprite design.
- Whether stage1 gets 2 or 3 parallax layers.
- Window default scale: recommend defaulting to 2× if 1× looks soft.

## Verification
- `swift test` in FightCore: all tests pass, goldens unchanged.
- SpriteSelection sheet test passes for all fighters; a new test checks `texelScale` parsing and
  node sizing (2× sheet yields the same logical size as the old 1× sheet).
- Release build; live playtest via scripts/playtest: screenshots of select, a match on each stage,
  hit/block sparks, KO. Compare against the PS1 screenshots in build/playtest.

## Update 2026-11-22: anime cel fighters
The fighter look described above (256-colour sheets, multi-step gradient shading, baked rim light) was
replaced by the user-approved anime designs: flat cel tones with one shadow tone per material, a
tinted indigo outline and 3/4 faces, drawn per fighter in `scripts/art/fighter_designs.py`. Everything
else here still holds for fighters: 224×224 cells, anchor (112, 220), 8 columns, `texelScale` 2,
unchanged frame names and `sheet.json`, stdlib-only deterministic generator, bilinear filtering.
Sheets are RGBA truecolour. Fighter PNGs total 8,399,008 bytes (7,699,802 before) and all Content
PNGs 10,143,997, which is over the ~8 MB aim under Constraints; the Release app is 13,193,190 bytes
against CI's 15,000,000 cap.

## Data contracts (fixed before parallel work)
- `sheet.json`: `{"texelScale": 2, "frames": [ {name,x,y,w,h,anchorX,anchorY}, ... ]}`; rects and anchors
  in sheet pixels. Legacy bare array = texelScale 1. `SpriteSheetLoader` exposes the scale.
  Shipped fighters: 224×224 cells, anchor (112, 220), COLS 8.
- `stage.json`: optional top-level `"texelScale": 2` applying to every layer; layer PNGs are
  `width*texelScale × height*texelScale`-ish (768×216 logical → 1536×432 texels). `StageLayerSpec`
  gains `texelScale: Int32` (default 1). stage1 moves to the `layers` schema.
- Halo/glow textures are generated at runtime in the app (no new Content files).
