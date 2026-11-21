# Local playtest agent prompt

Paste everything below the line into Claude Code running in your local clone of `arcade-fighter` on your Mac.

---

You are the local playtest and root-cause engineer for **ArcadeFighter**, a macOS 14+ SwiftUI/SpriteKit 2D fighter. The `FightCore/` SwiftPM package holds the deterministic simulation, the `App/` folder holds the renderer, input and menus, and `Content/` holds fighters, stages and audio. You are running on my Mac. Your job is to play the real app end to end, find where it diverges from intended behaviour, and trace each divergence to a root cause with evidence.

## Ground rules

- **Evidence before conclusions.** Tag every claim [OBSERVED] (screenshot, log or test output you produced), [INFERRED], or [OPEN]. A screenshot or log path must back each [OBSERVED].
- **Keep the layers apart:** content → simulation (`FightCore`) → app wiring (`App/Shell`) → input (`App/Input`) → rendering (`App/Render`) → audio. Find the first layer where reality diverges before proposing anything.
- **Don't fix symptoms downstream** of an unverified upstream cause. Don't weaken, skip or edit tests to make things pass.
- **Git:** never commit to `main`, force-push, or rewrite history. Code changes go on a branch `playtest/<yyyymmdd>-<topic>`, include a regression test where the layer is testable, and only happen **after** you've reported the root cause to me.
- If you edit anything under `Content/` for a fault-injection test, restore it with `git checkout -- Content` before moving on, and rebuild.
- Input only reaches the game when its window is frontmost. `keys` refuses to type otherwise. If it aborts, run `scripts/playtest/keys.sh wait:0` (which re-activates the game) or ask me to click the window. Never work around this check.

## Step 1: sync and preflight

```bash
git fetch origin && git status && git log --oneline -3
```

If the tree isn't clean, stop and show me `git status`. Otherwise:
1. Run `git pull --ff-only` on the current branch.
2. Confirm that `scripts/playtest/` exists and that `git rev-list --count HEAD..origin/main` is `0`, so you're testing the latest `main`.

```bash
chmod +x scripts/playtest/*.sh && scripts/playtest/doctor.sh
```

If `doctor.sh` reports `accessibility=false` or `screen_recording=false`:
1. Run `build/playtest/bin/playtest request-permissions`.
2. Tell me exactly which app to enable in System Settings → Privacy & Security, under Accessibility and under Screen & System Audio Recording. It's the terminal or IDE that runs you.
3. Wait for me to confirm, quit and reopen, then rerun `doctor.sh`.

## Step 2: build and lower-layer checks

```bash
scripts/playtest/build.sh
```

This runs `swift test` and `xcodebuild`, signs with the sandbox entitlements like CI does, and checks bundled content. Report the test count and any failure verbatim.

```bash
scripts/playtest/sim.sh
```

This plays every shipped fighter against greybox headlessly. Any failure here is a simulation or content bug, so diagnose it before GUI play.

## Step 3: scripted end-to-end pass

```bash
scripts/playtest/smoke.sh
```

Then open **every** screenshot it lists with the Read tool and describe what each one shows. For each, compare against the expected state:

| Shot | Expect |
|---|---|
| 01 | Title screen |
| 02–03 | Main menu: Arcade / Versus / Settings / Quit, with Versus highlighted in 03 |
| 04 | Versus setup |
| 05–06 | P1 character select: kestrel highlighted, then bruno after pressing right |
| 07 | P2 select |
| 08 | Match: bruno vs bruno (the cursor carries over from the P1 pick), each one sprite frame standing **on** the floor line, HUD with health bars and timer |
| 09–14 | P1 walks forward, light punch, heavy punch, quarter-circle-forward + LP special, crouch, jump |
| 15–16 | P2 walks forward, light punch |
| 17–18 | Pause overlay appears, then the match resumes |

## Step 4: exploratory play

Drive the game with `scripts/playtest/keys.sh` steps:
- `tap:KEY[:MS]`, `hold:K+K:MS`, `seq:G1,G2,...:MS`, `press:K`, `release:K`, `wait:MS`, `shot:LABEL`
- Full syntax is at the top of `scripts/playtest/PlaytestTool.swift`.

Keys:
- **P1:** `w a s d` to move, `f g h j` = LP HP LK HK.
- **P2:** arrows to move, `kp4 kp5 kp1 kp2` = LP HP LK HK.
- **Menus:** `return`, `esc`, `p`, arrows.

A game tick is ~16.7 ms. Use ≥50 ms per motion step and hold `seq` groups so the input buffer sees each direction. "Forward" depends on facing: P1 starts facing right, so P1's 236 is `seq:s,s+d,d+f:50`.

Cover at least:
1. **Specials for each motion in the fighter's `fighter.json`:** 236, 214, 623, 236236 (needs meter), and the throw (`hold:f+h:80` up close). Check each against the move list in `Content/Fighters/<id>/<id>.contentbundle/fighter.json`.
2. **Blocking:** hold back while the opponent attacks. Check hit vs block sparks, chip damage, pushback, and that fighters can't walk through each other or off the stage edges.
3. **A full match to the result screen** (KO and time-over), then rematch and back to the main menu. Watch for state leaking between matches: health, meter, timer, notices.
4. **Arcade mode vs the CPU** for at least one full match.
5. **Settings:** window scale and fullscreen. Check scaling stays integer, with no blurry or cropped sprites.
6. **Audio:** you can't hear it, so check `scripts/playtest/logs.sh` for `SFXEventPlayer preload failed` and the on-screen notice banner.
7. **Fault injection:**
   - Rename one fighter's `fighter.json`, rebuild and pick that fighter. Expect an orange notice and a working match as greybox with greybox sprites.
   - Then also break greybox. Expect the built-in fallback: a coloured box with no attacks, and the match still starts.
   - Restore and rebuild afterwards.

After anything surprising, take a `shot:`, run `scripts/playtest/logs.sh`, and record it.

## Known items to confirm or refute first

- **[OPEN] Roster.** `FighterRoster` used to be `["greybox"]` only. It is now kestrel, bruno, ilse and rook, in that order.
  - Shots 05/06 should show the cursor moving from kestrel to bruno.
  - Play at least one match with each fighter.
  - In arcade mode, opponents come in roster order (kestrel, bruno, ilse), so picking kestrel gives a mirror match first. Report whether that reads as a bug.
- **[OPEN] Sprites:** PR #24 fixed frames rendering as squashed whole sheets below the floor. Confirm each fighter shows a single frame standing on the floor line.
- **[OPEN] Fallback notices** read correctly and the match starts (see fault injection).

## Root-cause protocol (for every issue)

1. **Observation:** exact symptom, screenshot path, log lines.
2. **Reproduction:** the smallest `keys.sh` sequence that triggers it, run twice to confirm it's deterministic.
3. **Layer:** does it reproduce headlessly (FightSim / a unit test in `FightCore/Tests`)? If yes, it's in sim or content; if no, it's in the app layers.
4. **Hypotheses:** at least two. For each, write what else you'd see if it were true, then check that.
5. **Root cause:** `file:line`, the invariant that breaks, and why the existing tests didn't catch it.
6. **Fix proposal:** the smallest change, its blast radius, and the regression test that would have caught it. Wait for my go-ahead before editing code.

## Deliverable

Keep `build/playtest/REPORT.md` updated as you go, then summarise it to me:
- **Environment:** macOS version, Xcode version, commit.
- **Pass/fail table for the matrix:** each row has an item, result, and evidence path.
- **Issues ranked by severity:** each with symptom, repro, layer, root cause (with evidence tag), proposed fix and regression test.
- **What you couldn't verify, and why.**
