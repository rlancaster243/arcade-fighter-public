# Roster balance report (FIX-B kits)

Numbers are the authored `fighter.json` values for schema version 1. Walk speeds are Q8 raw units (`256` = 1 px/tick). Frame data, damage, and boxes the spec does not give were chosen in the FIX-B PR and are listed below. Greybox is unchanged.

On block, advantage is `blockstun - (active frames after the connecting hit + recovery)`. No authored strike is above +4. Throws and command grabs are unblockable, so they have no block advantage. Command grabs and Vesper Step use recovery of 22 or more so a 3-frame light can punish a whiff.

## 1. Character stats

| Fighter | Archetype | Health | Walk F / B (Q8) | Moves |
|---|---|---|---|---|
| Kestrel Vane | rushdown | 900 | 640 / 768 | 10 |
| Bruno "Anvil" Okafor | grappler | 1150 | 320 / 512 | 8 |
| Sister Ilse | zoner | 950 | 448 / 512 | 10 |
| Rook | armor/counter | 1000 | 448 / 512 | 9 |
| Greybox | test | 1000 | 768 / 512 | 7 |

Walk forward: Kestrel 640 (2.5 px), Bruno 320 (1.25 px), Ilse and Rook 448 (1.75 px). Walk back stays the previous speed, already stored as Q8: Kestrel 768 (3 px), Bruno, Ilse, Rook, and Greybox 512 (2 px).

## 2. Normals and throws

Kestrel and Bruno gained LK and HK. Existing LP, HP, and throw frame data on each fighter is unchanged. Throw input is `LP+LK`.

| Fighter | Move | Button | Startup | Active | Recovery | Damage | Meter | Hitstop | Guard |
|---|---|---|---|---|---|---|---|---|---|
| Kestrel Vane | Light Punch | LP | 3 | 2 | 5 | 70 | 130 | 6 | mid |
| Kestrel Vane | Heavy Punch | HP | 3 | 3 | 5 | 110 | 120 | 9 | mid |
| Kestrel Vane | Light Kick | LK | 3 | 2 | 5 | 60 | 110 | 6 | mid |
| Kestrel Vane | Heavy Kick | HK | 4 | 3 | 6 | 100 | 120 | 9 | mid |
| Kestrel Vane | Ice Toss | LP+LK | 3 | 1 | 5 | 130 | 120 | 6 | throw |
| Bruno "Anvil" Okafor | Light Punch | LP | 3 | 2 | 5 | 85 | 110 | 6 | mid |
| Bruno "Anvil" Okafor | Heavy Punch | HP | 3 | 3 | 5 | 140 | 120 | 9 | mid |
| Bruno "Anvil" Okafor | Light Kick | LK | 4 | 2 | 6 | 75 | 110 | 6 | mid |
| Bruno "Anvil" Okafor | Heavy Kick | HK | 5 | 3 | 7 | 120 | 120 | 9 | mid |
| Bruno "Anvil" Okafor | Slag Throw | LP+LK | 3 | 1 | 5 | 160 | 120 | 6 | throw |
| Sister Ilse | Light Punch | LP | 3 | 2 | 5 | 70 | 110 | 6 | mid |
| Sister Ilse | Heavy Punch | HP | 4 | 3 | 5 | 95 | 120 | 7 | mid |
| Sister Ilse | Light Kick | LK | 3 | 2 | 5 | 65 | 110 | 6 | mid |
| Sister Ilse | Heavy Kick | HK | 4 | 3 | 6 | 100 | 110 | 6 | mid |
| Sister Ilse | Throw | LP+LK | 3 | 1 | 5 | 120 | 120 | 6 | throw |
| Rook | Light Punch | LP | 3 | 2 | 5 | 75 | 120 | 6 | mid |
| Rook | Heavy Punch | HP | 5 | 3 | 7 | 120 | 120 | 9 | mid |
| Rook | Light Kick | LK | 3 | 2 | 5 | 65 | 120 | 6 | mid |
| Rook | Heavy Kick | HK | 4 | 3 | 6 | 100 | 120 | 6 | mid |
| Rook | Throw | LP+LK | 3 | 1 | 5 | 120 | 120 | 6 | throw |

## 3. Specials and supers

A strength variant is its own move with the same name. `P` accepts LP and HP. `K` accepts LK and HK. Each fighter has two special names and one super name.

| Fighter | Move | Motion | Button | S/A/R | Damage | Chip | Hitstop | Guard | Properties |
|---|---|---|---|---|---|---|---|---|---|
| Kestrel Vane | Rime Slide | 236 | LK | 3/7/14 | 80 | 20 | 8 | low | hits 2; vel x 0..896 y 0..0 |
| Kestrel Vane | Rime Slide | 236 | HK | 3/11/16 | 110 | 27 | 10 | low | hits 2; vel x 0..1280 y 0..0 |
| Kestrel Vane | Crag Hook | 623 | LP | 5/4/16 | 90 | 22 | 8 | high | vel x 0..256 y -1024..1024 |
| Kestrel Vane | Crag Hook | 623 | HP | 6/5/18 | 120 | 30 | 10 | high | invuln [0, 1]; vel x 0..256 y -1536..1536 |
| Kestrel Vane | Whiteout Line | 236236 | P | 4/10/18 | 55 | 40 | 10 | mid | hits 5; vel x 0..1024 y 0..0 |
| Bruno "Anvil" Okafor | Forge Quake | 214 | P | 8/2/18 | 0 | 0 | 8 | mid | projectile speed 1024 life 50 dmg 100 max 1 spawn 1 air False |
| Bruno "Anvil" Okafor | Bellows Lift | 236 | K | 5/2/22 | 150 | 0 | 9 | throw | whiffs vs airborne; vel x 0..256 y 0..0 |
| Bruno "Anvil" Okafor | Anvil Drop | 236236 | P | 8/3/26 | 260 | 0 | 10 | throw | whiffs vs airborne |
| Sister Ilse | Prayer Bead | 236 | LP | 10/3/14 | 0 | 0 | 8 | mid | projectile speed 768 life 70 dmg 60 max 1 spawn 1 air True |
| Sister Ilse | Prayer Bead | 236 | HP | 12/3/16 | 0 | 0 | 10 | mid | projectile speed 1792 life 50 dmg 80 max 1 spawn 1 air True |
| Sister Ilse | Vesper Step | 214 | LK | 5/1/22 | 0 | 0 | 8 | mid | vel x 0..9216 y 0..0 |
| Sister Ilse | Vesper Step | 214 | HK | 5/1/22 | 0 | 0 | 8 | mid | vel x -9216..0 y 0..0 |
| Sister Ilse | Rosary Storm | 236236 | P | 6/6/18 | 0 | 0 | 10 | mid | projectile speed 1280 life 80 dmg 45 max 4 spawn 4 air True |
| Rook | Rocket Jab | 236 | LP | 5/3/12 | 85 | 21 | 8 | mid | vel x 0..640 y 0..0 |
| Rook | Rocket Jab | 236 | HP | 7/4/16 | 120 | 30 | 10 | mid | armorHits 1; vel x 0..896 y 0..0 |
| Rook | Guard Protocol | 214 | P | 4/8/14 | 0 | 0 | 8 | mid | counter 0..<12 -> rook_norm_hp |
| Rook | Overclock Barrage | 236236 | K | 4/10/18 | 48 | 40 | 10 | mid | hits 5; vel x 0..768 y 0..0 |

## 4. Chosen frame data, damage, and boxes

Spec text did not give these numbers. Hitstop is light 6, heavy 9, special 8–10, super 10. Strike boxes are integer rects from the bottom-centre anchor, facing right.

- Shared strike box `x 16, y -72, w 40, h 40`. Low strike `x 12, y -36, w 44, h 28` with low hurt `x -28, y -40, w 56, h 36`. Anti-air `x 4, y -130, w 36, h 90`. Throw box `x 4, y -80, w 44, h 72` (Anvil Drop `w 52, h 76`). Bead `x -12, y -70, w 24, h 24`. Ground wave `x -16, y -28, w 32, h 24`. Moves that should not strike with their body use a zero-size hit box.
- Kestrel LK `3/2/5`, damage 60, hitstop 6, meter 110. Kestrel HK `4/3/6`, damage 100, hitstop 9, meter 120.
- Bruno LK `4/2/6`, damage 75, hitstop 6, meter 110. Bruno HK `5/3/7`, damage 120, hitstop 9, meter 120.
- Rime Slide LK `3/7/14`, dash 896 Q8 for 9 ticks, hits on active frames 5–6, damage 80, chip 20, hitstop 8, guard low. HK `3/11/16`, dash 1280 Q8 for 13 ticks, hits on frames 9–10, damage 110, chip 27, hitstop 10.
- Crag Hook LP `5/4/16`, rise −1024 Q8 for 2 ticks then +1024 for 2 ticks, damage 90, chip 22, hitstop 8, guard high. HP `6/5/18`, rise −1536 Q8 for 3 ticks then +1536 for 3 ticks, invulnerable on state ticks 0 and 1, damage 120, chip 30, hitstop 10.
- Whiteout Line `4/10/18`, five hits (55×4 then 70) on active frames 1, 3, 5, 7, 9, hitstop 10, dash 1024 Q8 for 12 ticks, meter gain 30 per connecting hit.
- Forge Quake `8/2/18`, projectile speed 1024, lifetime 50, damage 100, one on screen, ground-only. The body does not hit.
- Bellows Lift `5/2/22`, damage 150, hitstop 9, 256 Q8 step for 5 ticks, guard throw. Anvil Drop `8/3/26`, damage 260, hitstop 10, guard throw, whiffs versus airborne.
- Prayer Bead LP `10/3/14`, speed 768, lifetime 70, damage 60. HP `12/3/16`, speed 1792, lifetime 50, damage 80. Both maxOnScreen 1 and hit airborne. Rosary Storm `6/6/18` spawns 4 beads, speed 1280, lifetime 80, damage 45, maxOnScreen 4.
- Vesper Step both versions `5/1/22`, one tick of ±9216 Q8 (36 px) on state tick 3, damage 0, hitstop 8.
- Rocket Jab LP `5/3/12`, forward 640 Q8 for 8 ticks, damage 85, chip 21, hitstop 8. HP `7/4/16`, forward 896 Q8 for 11 ticks, damage 120, chip 30, hitstop 10, armorHits 1.
- Guard Protocol `4/8/14`, counter window state ticks 0 until 12, follow-up `rook_norm_hp`, body does not hit, hitstop 8. Overclock Barrage `4/10/18`, five hits on frames 0, 2, 4, 6, 8 (48×4 then 60), forward 768 Q8 for 14 ticks, hitstop 10.

## 5. Source paths

| Fighter | Content bundle |
|---|---|
| kestrel | `Content/Fighters/kestrel/kestrel.contentbundle/fighter.json` |
| bruno | `Content/Fighters/bruno/bruno.contentbundle/fighter.json` |
| ilse | `Content/Fighters/ilse/ilse.contentbundle/fighter.json` |
| rook | `Content/Fighters/rook/rook.contentbundle/fighter.json` |
| greybox | `Content/Fighters/greybox/greybox.contentbundle/fighter.json` |

Schema reference: `docs/fighter-schema.md`.
