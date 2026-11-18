# FIX-D balance report

FightSim roster mode on the four shipped fighters, both sides hard, stage `stage1`. A match runs until `matchOver` or the 59400-tick cap. All 2000 matches completed. Draws: 0.

Unordered pairings are 200 matches. Seeds 1–100 put the lexicographically first fighter id on P1. Seeds 101–200 swap sides. Mirrors are seeds 1–200 with the same fighter on both sides.

Win rate is that fighter's wins divided by 200. P1-side rate is P1 wins divided by 200. Engagement distance is the sample-weighted mean horizontal separation in pixels on ticks where both fighters are alive and the round is not over, across the 800 matches that fighter played (three pairings plus the mirror). Throws per match are `throwHit` events credited to that fighter, divided by 800.

## Pairing win rate (band 40–60%)

| Pairing | Wins | Win rate | Band |
|---|---|---|---|
| Bruno "Anvil" Okafor vs Sister Ilse | 89–111 | 44.5% Bruno "Anvil" Okafor | pass |
| Bruno "Anvil" Okafor vs Kestrel Vane | 92–108 | 46.0% Bruno "Anvil" Okafor | pass |
| Bruno "Anvil" Okafor vs Rook | 115–85 | 57.5% Bruno "Anvil" Okafor | pass |
| Sister Ilse vs Kestrel Vane | 104–96 | 52.0% Sister Ilse | pass |
| Sister Ilse vs Rook | 84–116 | 42.0% Sister Ilse | pass |
| Kestrel Vane vs Rook | 117–83 | 58.5% Kestrel Vane | pass |

## Mirror P1-side rate (band 45–55%)

| Fighter | P1–P2 | P1-side | Band |
|---|---|---|---|
| Bruno "Anvil" Okafor | 95–105 | 47.5% | pass |
| Sister Ilse | 92–108 | 46.0% | pass |
| Kestrel Vane | 92–108 | 46.0% | pass |
| Rook | 97–103 | 48.5% | pass |

## Engagement distance and throws

Band: Ilse above Rook, and Rook above both Kestrel and Bruno. Bruno has the most throws per match.

| Fighter | Engagement distance | Throws per match | Throws |
|---|---|---|---|
| Sister Ilse | 205.07 px | 0.000 | 0 |
| Rook | 131.35 px | 0.000 | 0 |
| Bruno "Anvil" Okafor | 130.74 px | 2.413 | 1930 |
| Kestrel Vane | 119.69 px | 0.000 | 0 |

Distance order holds: pass. Rook is 0.61 px above the closer of Bruno and Kestrel. Bruno throws the most: pass.

Raw reports: `docs/balance/sim/`.
