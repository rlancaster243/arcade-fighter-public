# Audio credits

`hit_light.wav`, `hit_heavy.wav`, `block.wav`, `throw.wav` and `ko.wav` are trimmed, converted
and (for `block`) low-pass filtered excerpts of two CC0 packs from OpenGameArt. CC0 needs no
attribution; credit is given here anyway.

| Clip | Source pack | Source file |
|---|---|---|
| `hit_light` | [37 hits/punches](https://opengameart.org/content/37-hitspunches) (CC0) | `hit10` |
| `hit_heavy` | [37 hits/punches](https://opengameart.org/content/37-hitspunches) (CC0) | `hit22` |
| `block` | [12 wet towel hitting/falling/punching floor sounds](https://opengameart.org/content/12-wet-towel-hittingfallingpunching-floor-sounds) (CC0) | `wet_towel_on_floor-03` |
| `throw` | same wet towel pack | `wet_towel_on_floor-07` |
| `ko` | same wet towel pack | `wet_towel_on_floor-12` (from the floor impact onward) |

The license shown on both OpenGameArt pages is CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/).
The towel pack's bundled `*-info.txt` carries a generic multi-license header (MIT/zlib/BSD);
the OpenGameArt page, which lists CC0, is treated as authoritative.

Processing is reproducible with `scripts/audio/build_cc0_sfx.py` (macOS `afconvert` plus the
Python standard library): FLAC to 44.1 kHz mono 16-bit WAV, leading silence trimmed, tail faded,
peak-normalised to 0.9. Playback level is set by `gainQ8` in `manifest.json`.

The remaining clips (`special`, `super`, `round_start`, `whiff`, `time_over`, `ambient_bells`)
are synthesized by `FightCore/Tests/ContentTests/L10/helpers/gen_l10_assets.sh`.
