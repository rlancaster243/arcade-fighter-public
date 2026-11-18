# Roster balance report (Phase 2)

Snapshot of playable fighter content on `main` as of schema version 1. All numbers are taken from each fighter’s `fighter.json` under `Content/Fighters/<id>/<id>.contentbundle/`. No sim or engine constants are changed here—only documented.

**Roster covered:** `kestrel`, `bruno`, `ilse`, `rook`, `greybox` (present in Content; `greybox` remains the Phase 0 contract dummy).

---

## How to read this report

| Term | Meaning |
|------|---------|
| **Total** | `startup + active + recovery` for the move (attack animation length in ticks). |
| **Chip** | Block damage on specials/supers only (content field; engine applies 25% rules on block). |
| **Meter gain** | `meterGain` on the move (attacker on hit; half on block per match rules). |
| **Super cost** | Not stored in `fighter.json`. Every super (`236236` + button) spends **1000** meter at startup (`MatchRules.superMeterCost`). |

Shared across the roster unless noted:

- Jump: `velocityY -3584`, `gravity 256`
- Default hitstun / blockstun on strikes: **12** / **8**
- Throw frame shell: **3 + 1 + 5** (total 9)
- Most strike families: **3 + 2 + 5** (LP), **3|4|5 + 3 + 5|6|7** (HP), specials **3 + 4 + 5** (QCF/QCB) or **3 + 3 + 5** (DP), supers **3 + 6 + 5**

---

## 1. Character stats

| Fighter | Archetype | Health | Walk F / B | Move count |
|---------|-----------|--------|------------|------------|
| Kestrel Vane | rushdown | 950 | **4** / 3 | 7 |
| Bruno Okafor | brawler | **1050** | 2 / 2 | 7 |
| Sister Ilse | sister | 950 | 3 / 2 | **9** (includes LK/HK) |
| Rook | rook | **1050** | 2 / 2 | **9** (includes LK/HK) |
| Greybox | test | 1000 | 3 / 2 | 7 |

**Movement:** Kestrel is the only roster member with faster forward walk (4) and retain back-walk 3. Bruno and Rook trade speed for 100 extra HP. Ilse sits between Kestrel and the tanks on walks.

**Kit breadth:** Ilse and Rook ship four standing normals (LP/HP/LK/HK); L9 pair (Kestrel/Bruno) and Greybox only define LP/HP in content.

---

## 2. Normals — frame data and damage

### Light punch (stand LP)

| Fighter | Startup | Active | Recovery | Total | Damage | Meter gain | Hitstop |
|---------|---------|--------|----------|-------|--------|------------|---------|
| Kestrel | 3 | 2 | 5 | 10 | 70 | **130** | 6 |
| Bruno | 3 | 2 | 5 | 10 | **85** | 110 | 6 |
| Ilse | 3 | 2 | 5 | 10 | 70 | 110 | 6 |
| Rook | 3 | 2 | 5 | 10 | 75 | 120 | 6 |
| Greybox | 3 | 2 | 5 | 10 | 80 | 120 | 6 |

Kestrel is the only fighter with **above-baseline meter on LP** (130) but ties for lowest damage (70). Bruno’s LP is the heaviest at 85 with no frame tax.

### Heavy punch (stand HP)

| Fighter | Startup | Active | Recovery | Total | Damage | Meter gain | Hitstop |
|---------|---------|--------|----------|-------|--------|------------|---------|
| Kestrel | 3 | 3 | 5 | 11 | 110 | 120 | 9 |
| Bruno | 3 | 3 | 5 | 11 | **140** | 120 | 9 |
| Ilse | **4** | 3 | 5 | **12** | 95 | 120 | 7 |
| Rook | **5** | 3 | **7** | **15** | 120 | 120 | 9 |
| Greybox | 3 | 3 | 5 | 11 | 80 | 120 | 6 |

Bruno’s HP leads on damage (140) with the same 11-frame shell as Kestrel. Rook pays **+4 frames** over the fast heavy (15 total) for 120 damage—clear tank pacing. Ilse’s HP is slower than Kestrel/Bruno (12f) for mid-tier damage.

### Extra normals (Ilse / Rook only)

| Fighter | Move | Total | Damage | Notes |
|---------|------|-------|--------|-------|
| Ilse | LK | 10 | 65 | Same cadence as LP |
| Ilse | HK | **13** | 100 | 4+3+6; slower heavy kick |
| Rook | LK | 10 | 65 | Mirrors Ilse LK |
| Rook | HK | **13** | 100 | Same HK profile as Ilse |

---

## 3. Specials — frame data, damage, chip, meter

Frame totals match **QCF/QCB: 12f**, **DP: 11f** for all roster members with standard mappings. Button mappings differ on Rook (see inputs table).

### Quarter-circle forward (`236`)

| Fighter | Move | Button | Damage | Chip | Meter gain | Hitstop | Guard |
|---------|------|--------|--------|------|------------|---------|-------|
| Kestrel | Frost Cut | LP | 95 | 24 | 120 | 6 | mid |
| Bruno | Quarry Rush | LP | 115 | **28** | 120 | 6 | mid |
| Ilse | Prayer Beam | LP | 110 | 25 | 120 | **9** | mid |
| Rook | Castle Slam | **HP** | **130** | 20 | 120 | 6 | mid |
| Greybox | QCF Special | LP | 80 | 20 | 120 | 6 | mid |

**Damage spread:** 80 (greybox) → 130 (Rook Castle Slam). Bruno and Ilse QCFs are premium chip (25–28) relative to Rook’s 20.

### Quarter-circle back (`214`)

| Fighter | Move | Button | Damage | Chip | Guard |
|---------|------|--------|--------|------|-------|
| Kestrel | Glacier Step | LK | 85 | 22 | mid |
| Bruno | Stone Shove | LK | 90 | 22 | mid |
| Ilse | Sanctified Step | LK | 80 | 20 | mid |
| Rook | Bulwark Spin | **LP** | 80 | 20 | **low** |
| Greybox | QCB Special | LK | 80 | 20 | mid |

Rook alone has a **low** QCB; everyone else uses mid. Damage cluster is tight (80–90).

### Dragon punch (`623`)

| Fighter | Move | Button | Damage | Chip | Guard |
|---------|------|--------|--------|------|-------|
| Kestrel | Kestrel Rise | HP | **100** | **25** | mid |
| Bruno | Forge Upper | HP | **125** | **30** | mid |
| Ilse | Rising Censer | HP | 80 | 20 | **high** |
| Rook | Upward Baton | **LK** | 80 | 20 | mid |
| Greybox | DP Special | HP | 80 | 20 | mid |

Ilse’s DP is the only **high** anti-air profile in the set. Bruno’s DP is the top damage/chip DP; Kestrel sits in the middle.

### Special input summary (content)

| Fighter | `236` | `214` | `623` |
|---------|-------|-------|-------|
| Kestrel, Bruno, Ilse, Greybox | LP | LK | HP |
| Rook | HP | LP | LK |

---

## 4. Supers — damage, chip, frames, meter

All supers: **3 + 6 + 5 = 14** frames, **meter cost 1000** (global, not per-move JSON).

| Fighter | Super | Damage | Chip | Meter gain (on hit) | Hitstop (content) |
|---------|-------|--------|------|---------------------|-------------------|
| Kestrel | Blizzard Waltz | 280 | 70 | 120 | 10 |
| Bruno | Forge Break | **320** | **80** | 120 | 10 |
| Ilse | Choir of Bells | 280 | 70 | 120 | 10 |
| Rook | Rook Checkmate | 300 | **20** | 120 | **6** |
| Greybox | Super | 80 | 20 | 120 | 6 |

**Relative power:** Bruno super leads raw damage and chip. Kestrel and Ilse tie at 280/70. Rook sits between on damage (300) but chip is an outlier (20 vs 70–80 elsewhere)—worth a design pass if chip parity with other supers is intended.

**Hitstop:** Content lists 10 for Kestrel/Bruno/Ilse supers (matches engine super minimum). Rook and Greybox list 6; engine may still floor supers at 10 via `HitstopRules`—confirm in playtests.

---

## 5. Throws

| Fighter | Damage | Total frames | Meter gain |
|---------|--------|--------------|------------|
| Kestrel | 130 | 9 | 120 |
| Bruno | **160** | 9 | 120 |
| Ilse | 120 | 9 | 120 |
| Rook | 120 | 9 | 120 |
| Greybox | 120 | 9 | 120 |

Bruno’s throw is **+30** over the 120 baseline and **+30** over Kestrel—consistent with brawler damage bias. Frame data is identical across the roster.

---

## 6. Meter economy (content-only)

### Meter gain on hit (`meterGain`)

| Value | Moves |
|-------|--------|
| **130** | Kestrel LP only |
| **120** | Most HP, all specials, supers, throws (Kestrel/Bruno/Ilse/Rook/Greybox bulk) |
| **110** | Bruno LP; Ilse LP/LK/HK |

Kestrel’s LP is the fastest meter-positive light in the roster. Ilse and Bruno gain less meter per light than tanks/Rook despite similar frame data.

### Super spend and earn

- **Spend:** 1000 per super activation (not authored in JSON).
- **Earn:** Primarily `meterGain` on confirmed hits; defender gains meter from damage taken (sim rule, not in fighter JSON).
- **Rough lights-to-super (attacker, all hits):** at 110–130 per LP, ~8–10 clean lights before a super—faster for Kestrel LP, slower for 110-gain lights.

No fighter defines a cheaper or more expensive super in content; balance differences are damage/chip and how quickly each kit builds meter via normals.

---

## 7. Cross-roster observations

1. **Two HP tiers:** 950 (Kestrel, Ilse) vs 1050 (Bruno, Rook). Greybox at 1000 is the neutral reference.
2. **Brawlers scale damage:** Bruno leads normals, QCF, DP, super, and throw. Frame shells stay aligned with others—power is mostly numbers, not frame traps.
3. **Rushdown tax is subtle:** Kestrel trades LP damage for speed and extra LP meter; supers are not stronger than Ilse’s—mobility is the main perk.
4. **Ilse zoner hints:** Strong QCF (110) and high DP; lows are not in this JSON slice—QCB is standard mid 80.
5. **Rook anomalies:** Slowest HP (15f), strongest single special (Castle Slam 130), low super chip, nonstandard special buttons, only low-guard QCB in the roster.
6. **Greybox flat 80:** Useful baseline; every production fighter diverges on at least one axis (health, walks, or move damage).
7. **Stun parity:** Identical 12/8 hit and block stun on almost all moves—balance is damage, chip, frames, and walks—not stun shapes.
8. **Content gaps vs full buttons:** Kestrel/Bruno lack LK/HK move entries; comparing full button coverage to Ilse/Rook is asymmetric until L9 kits are extended.

---

## 8. Source paths

| Fighter | Content bundle |
|---------|------------------|
| kestrel | `Content/Fighters/kestrel/kestrel.contentbundle/fighter.json` |
| bruno | `Content/Fighters/bruno/bruno.contentbundle/fighter.json` |
| ilse | `Content/Fighters/ilse/ilse.contentbundle/fighter.json` |
| rook | `Content/Fighters/rook/rook.contentbundle/fighter.json` |
| greybox | `Content/Fighters/greybox/greybox.contentbundle/fighter.json` |

Schema reference: `docs/fighter-schema.md`.

---

*Phase 2 slice — documentation only; no JSON or code changes.*