# Roster balance report (FIX-B kits)

Numbers are the authored `fighter.json` values for schema version 1. Walk speeds are Q8 raw units (`256` = 1 px/tick). Frame data, damage, and boxes the spec does not give were chosen in the FIX-B PR and are listed below. FIX-D retuned damage, stun, pushback, hitboxes, and move velocity. Ilse bead speed stays LP 768 and HP 1792; bead damage changed. Names, inputs, archetypes, health, walk speeds, Rocket Jab armor, one bead on screen, grab rules, and Guard Protocol's counter are unchanged. Sections 2–4 match the tuned JSON. Greybox is unchanged.

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

On block, advantage is `blockstun - (active frames after the connecting hit + recovery)`. No authored strike is above +4. Throws and command grabs are unblockable.

| Fighter | Move | Button | Startup | Active | Recovery | Damage | Hitstun | Pushback | Meter | Hitstop | Guard |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Kestrel Vane | Light Punch | LP | 3 | 2 | 5 | 72 | 14 | 4 | 130 | 6 | mid |
| Kestrel Vane | Heavy Punch | HP | 3 | 3 | 5 | 108 | 14 | 4 | 120 | 9 | mid |
| Kestrel Vane | Light Kick | LK | 3 | 2 | 5 | 64 | 14 | 4 | 110 | 6 | mid |
| Kestrel Vane | Heavy Kick | HK | 4 | 3 | 6 | 100 | 14 | 4 | 120 | 9 | mid |
| Kestrel Vane | Ice Toss | LP+LK | 3 | 1 | 5 | 130 | 12 | 4 | 120 | 6 | throw |
| Bruno "Anvil" Okafor | Light Punch | LP | 3 | 2 | 5 | 70 | 16 | 6 | 110 | 6 | mid |
| Bruno "Anvil" Okafor | Heavy Punch | HP | 3 | 3 | 5 | 90 | 16 | 6 | 120 | 9 | mid |
| Bruno "Anvil" Okafor | Light Kick | LK | 4 | 2 | 6 | 62 | 16 | 6 | 110 | 6 | mid |
| Bruno "Anvil" Okafor | Heavy Kick | HK | 5 | 3 | 7 | 86 | 16 | 6 | 120 | 9 | mid |
| Bruno "Anvil" Okafor | Slag Throw | LP+LK | 3 | 1 | 5 | 160 | 12 | 4 | 120 | 6 | throw |
| Sister Ilse | Light Punch | LP | 3 | 2 | 5 | 70 | 12 | 4 | 110 | 6 | mid |
| Sister Ilse | Heavy Punch | HP | 4 | 3 | 5 | 96 | 18 | 86 | 120 | 7 | mid |
| Sister Ilse | Light Kick | LK | 3 | 2 | 5 | 50 | 18 | 56 | 110 | 6 | mid |
| Sister Ilse | Heavy Kick | HK | 4 | 3 | 6 | 90 | 18 | 86 | 110 | 6 | mid |
| Sister Ilse | Throw | LP+LK | 3 | 1 | 5 | 120 | 12 | 4 | 120 | 6 | throw |
| Rook | Light Punch | LP | 3 | 2 | 5 | 92 | 14 | 50 | 120 | 6 | mid |
| Rook | Heavy Punch | HP | 5 | 3 | 7 | 225 | 14 | 50 | 120 | 9 | mid |
| Rook | Light Kick | LK | 3 | 2 | 5 | 64 | 14 | 50 | 120 | 6 | mid |
| Rook | Heavy Kick | HK | 3 | 3 | 6 | 100 | 14 | 50 | 120 | 6 | mid |
| Rook | Throw | LP+LK | 3 | 1 | 5 | 120 | 12 | 4 | 120 | 6 | throw |

## 3. Specials and supers

| Fighter | Move | Motion | Button | S/A/R | Damage | Hitstop | Guard | Properties |
|---|---|---|---|---|---|---|---|---|
| Kestrel Vane | Rime Slide | 236 | LK | 3/7/14 | 80 | 8 | low | hits 2; vel x 896..896 |
| Kestrel Vane | Rime Slide | 236 | HK | 3/11/16 | 110 | 10 | low | hits 2; vel x 1280..1280 |
| Kestrel Vane | Crag Hook | 623 | LP | 5/4/16 | 90 | 8 | high | vel x 256..256 |
| Kestrel Vane | Crag Hook | 623 | HP | 6/5/18 | 120 | 10 | high | invuln [0, 1]; vel x 256..256 |
| Kestrel Vane | Whiteout Line | 236236 | P | 4/10/18 | 55 | 10 | mid | hits 5; vel x 1024..1024 |
| Bruno "Anvil" Okafor | Forge Quake | 214 | P | 8/2/18 | 0 | 8 | mid | projectile speed 1024 life 50 dmg 100 max 1 spawn 1 air False |
| Bruno "Anvil" Okafor | Bellows Lift | 236 | K | 5/2/22 | 90 | 9 | throw | whiffs vs airborne; unblockable; vel x 256..256 |
| Bruno "Anvil" Okafor | Anvil Drop | 236236 | P | 8/3/26 | 260 | 10 | throw | whiffs vs airborne; unblockable |
| Sister Ilse | Prayer Bead | 236 | LP | 10/3/14 | 0 | 8 | mid | projectile speed 768 life 70 dmg 108 max 1 spawn 1 air True |
| Sister Ilse | Prayer Bead | 236 | HP | 12/3/16 | 0 | 10 | mid | projectile speed 1792 life 50 dmg 132 max 1 spawn 1 air True |
| Sister Ilse | Vesper Step | 214 | LK | 5/1/22 | 0 | 8 | mid | vel x 9216..9216 |
| Sister Ilse | Vesper Step | 214 | HK | 5/1/22 | 0 | 8 | mid | vel x -9216..-9216 |
| Sister Ilse | Rosary Storm | 236236 | P | 6/6/18 | 0 | 10 | mid | projectile speed 1280 life 80 dmg 45 max 4 spawn 4 air True |
| Rook | Rocket Jab | 236 | LP | 5/3/12 | 96 | 8 | mid | vel x 461..461 |
| Rook | Rocket Jab | 236 | HP | 7/4/16 | 180 | 10 | mid | armorHits 1; vel x 645..645 |
| Rook | Guard Protocol | 214 | P | 4/8/14 | 0 | 8 | mid | counter 0..<12 -> rook_norm_hp |
| Rook | Overclock Barrage | 236236 | K | 4/10/18 | 48 | 10 | mid | hits 5; vel x 768..768 |

## 4. FIX-D tuning

Hitstop stays in the FIX-B bands (specials 8–10, supers 10). Strike block advantage stays at or below +4. Prayer Bead LP speed stays 768 and HP speed stays 1792. Rocket Jab HP keeps `armorHits` 1. Bellows Lift and Anvil Drop stay guard throw, unblockable, and whiff versus airborne. Guard Protocol still counters into `rook_norm_hp`. Names, inputs, archetypes, health, and walk speeds are unchanged.

Normals on Kestrel and Bruno step forward. Ilse's HP and HK step back and push on hit. Rook's normals step forward with more pushback. Bellows Lift damage is 90. Ilse bead damage is LP 108 and HP 132. The FightSim bands are in `docs/balance/fix-d-summary.md`.
## 5. Source paths

| Fighter | Content bundle |
|---|---|
| kestrel | `Content/Fighters/kestrel/kestrel.contentbundle/fighter.json` |
| bruno | `Content/Fighters/bruno/bruno.contentbundle/fighter.json` |
| ilse | `Content/Fighters/ilse/ilse.contentbundle/fighter.json` |
| rook | `Content/Fighters/rook/rook.contentbundle/fighter.json` |
| greybox | `Content/Fighters/greybox/greybox.contentbundle/fighter.json` |

Schema reference: `docs/fighter-schema.md`.

Rocket Jab damage was 32 (LP) and 45 (HP) while every active frame connected, which made it 96 and 180 in play. Attacks now connect once, so the listed damage is the full amount: 96 (chip 42) and 180 (chip 80).
