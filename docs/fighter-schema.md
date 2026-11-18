# Fighter content schema (schemaVersion 1)

One folder per fighter (e.g. `Content/Fighters/greybox/`) containing:

- `fighter.json` — definition and moves
- Sprite sheet PNG (indexed, 112×112 cells, ≤16 colours + optional alternate palettes)
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
| `walkForward` | integer | yes | Pixels per tick (logical) |
| `walkBack` | integer | yes | Pixels per tick |
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
| `unblockable` | boolean | Only allowed when `guard` is `throw` |

## sheet.json

Array of frames:

```json
[{ "name": "idle_0", "x": 0, "y": 0, "w": 112, "h": 112, "anchorX": 56, "anchorY": 112 }]
```

Anchor is bottom-centre of the cell.

## Validation failures (load error, never silent default)

- Wrong `schemaVersion`
- Duplicate move `id`
- Negative `startup` / `active` / `recovery`
- Box arrays not matching frame counts for a phase
- Sprite `name` referenced in moves missing from `sheet.json`
- `unblockable: true` when guard is not throw
- Empty `gamePlan`
- Missing sheet or sprite references