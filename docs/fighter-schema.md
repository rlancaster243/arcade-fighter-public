# Fighter content schema (schemaVersion 1)

One bundle per fighter (e.g. `Content/Fighters/greybox/greybox.contentbundle/`) with macOS `Info.plist` (`CFBundlePackageType` = `BNDL`, no `CFBundleExecutable`), containing:

- `fighter.json` — definition and moves
- Sprite sheet PNG (shipped fighters: RGBA straight alpha, 224×224 cells at texelScale 2; greybox stays 1×, 112×112 indexed)
- `sheet.json` — sprite frame metadata

## fighter.json

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `schemaVersion` | integer | yes | Must be `1` |
| `id` | string | yes | Unique fighter id |
| `displayName` | string | yes | HUD label |
| `archetype` | string | yes | Design tag |
| `gamePlan` | string | yes | Non-empty design note |
| `health` | integer | yes | Round start health |
| `walkForward` | integer | yes | Q8 px/tick (`256` = 1 px). Must be ≥ 0 |
| `walkBack` | integer | yes | Q8 px/tick (`256` = 1 px). Must be ≥ 0 |
| `jump` | object | yes | `velocityY`, `gravity` integers |
| `pushbox` | box | yes | Standing pushbox |
| `hurtboxes` | array | yes | `{ "state": "<FighterStateKind>", "boxes": [box] }` per state |
| `spriteSheet` | string | yes | Path to PNG relative to fighter folder |
| `sheetMeta` | string | yes | Path to `sheet.json` relative to fighter folder |
| `moves` | array | yes | Move definitions |

### box

Integer rectangle from bottom-centre anchor, facing right: `x`, `y`, `w`, `h`.

### move

| Field | Type | Notes |
|-------|------|-------|
| `id` | string | Unique within fighter |
| `name` | string | Display |
| `input` | object | Normal: `button` + `stance`; special: `motion` + `button`; super: `236236` + `button` |
| `startup` / `active` / `recovery` | integer | Frame counts ≥ 0 |
| `frames` | object | Per-phase box arrays length must match phase frame counts |
| `damage`, `chip`, `hitstun`, `blockstun` | integer | Combat data |
| `pushbackHit`, `pushbackBlock` | integer | |
| `meterGain`, `hitstop` | integer | |
| `guard` | string | `high`, `mid`, `low`, `throw` |
| `unblockable` | boolean | Only allowed when `guard` is `throw`. Omitted means false |
| `armorHits` | integer | Omitted means `0`. Hits absorbed before this attack takes hitstun. Must be ≥ 0 |
| `projectile` | object | Omitted means the move spawns nothing. See projectile |
| `velocities` | array | Omitted or empty means no per-frame velocity. See velocity |
| `invulnerableFrames` | array of integer | `stateTick` values that are invulnerable. Omitted means none |
| `whiffsVsAirborne` | boolean | Command grab: no connect against `airborne`. Only when `guard` is `throw`. Omitted means false |
| `counter` | object | Counter window. Omitted means no counter. See counter |
| `hits` | array | Multi-hit specs. Omitted means every active frame uses the move's damage. See hit |

### projectile

Required keys when the object is present:

| Field | Type | Notes |
|-------|------|-------|
| `speed` | integer | Q8 magnitude along facing. Positive moves forward. `256` = 1 px/tick |
| `lifetime` | integer | Ticks until the projectile expires. Must be > 0 |
| `hitbox` | box | Must have `w` > 0 and `h` > 0 |
| `damage` | integer | Must be ≥ 0 |
| `maxOnScreen` | integer | Owner's active projectiles must be below this to spawn another. Must be > 0 |
| `spawnCount` | integer | How many projectiles this activation spawns. Must be ≥ 1 and ≤ `active` |
| `hitsAirborne` | boolean | `false` skips defenders in `airborne` (ground-only shockwaves) |

Spawn rule: on each active frame index `i` with `0 ≤ i < spawnCount` (`stateTick == startup + i`), spawn one projectile if the owner has fewer than `maxOnScreen` active projectiles. A volley sets `spawnCount` above 1 and `active` at least that large.

### velocity

Each element is `{ "x": <Q8>, "y": <Q8> }`. When present, the array length must equal `startup + active + recovery`. Element `i` is applied on the settled `stateTick == i`. The tick an attack starts settles at `stateTick` 0 (velocity, invulnerability, and hitboxes for that index apply before the tick advances). Each later tick advances once, then applies that index. `x` is facing-right and is mirrored when the fighter faces left. `y` uses jump sign (negative is up). One large `x` on a single tick is a teleport; several forward samples are a dash.

### counter

| Field | Type | Notes |
|-------|------|-------|
| `startTick` | integer | Inclusive `stateTick`. Must be ≥ 0 |
| `endTick` | integer | Exclusive. Must be greater than `startTick` and ≤ total frames |
| `followUpMoveID` | string | Must name another move on this fighter |

A non-throw strike that connects inside the window is negated. `followUpMoveID` is applied immediately as a hit using that move's damage, hitstun, blockstun, and hitstop. Throws ignore the window.

### hit

| Field | Type | Notes |
|-------|------|-------|
| `activeFrame` | integer | Index within the active window. Must be unique and in `0 ..< active` |
| `damage`, `hitstun`, `blockstun`, `hitstop` | integer | Must be ≥ 0 |

When `hits` is non-empty, active frames that are not listed do not connect.

## sheet.json

Object with a texel scale and the frames:

```json
{ "texelScale": 2,
  "frames": [{ "name": "idle_0", "x": 0, "y": 0, "w": 224, "h": 224, "anchorX": 112, "anchorY": 220 }] }
```

- `texelScale` (integer, default 1): texels per logical pixel. Rects and anchors are in sheet
  pixels; nodes are sized `w / texelScale` by `h / texelScale`, so logical sizes and anchors
  keep their meaning.
- A bare array of frames is still accepted and means `texelScale` 1 (greybox and fixtures use it).
- Shipped fighters (kestrel, bruno, ilse, rook): 224×224 cells, 8 columns, anchor `(112, 220)`
  (feet 4 texels above the cell bottom), RGBA PNG with straight alpha, `texelScale` 2.
  Projectile frames (`proj_*`) anchor at the cell centre, `(112, 112)`.
- Generated by `scripts/art/gen_fighters.py`; greybox is a separate 1× asset it does not touch.

## Validation failures (load error, never silent default)

- Wrong `schemaVersion`
- Duplicate move `id`
- Negative `startup` / `active` / `recovery`
- Box arrays not matching frame counts for a phase
- Sprite `name` referenced in moves missing from `sheet.json`
- `unblockable: true` when guard is not throw
- Empty `gamePlan`
- Missing sheet or sprite references
- Negative `walkForward` or `walkBack`
- Negative `armorHits`
- Projectile `lifetime` ≤ 0, `spawnCount` outside `1...active`, `maxOnScreen` ≤ 0, negative `damage`, or hitbox `w`/`h` ≤ 0
- `velocities` length other than `startup + active + recovery`
- `invulnerableFrames` out of range or duplicated
- `whiffsVsAirborne: true` when guard is not throw
- Counter window outside the move, or `followUpMoveID` missing
- Multi-hit `activeFrame` out of range or duplicated, or negative hit damage/stun/hitstop