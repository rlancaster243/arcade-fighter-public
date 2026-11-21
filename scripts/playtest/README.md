# Playtest kit (macOS)

These scripts let a person or a local Claude Code session build, launch, drive and inspect the real app. Output goes to `build/playtest/` (gitignored).

| Script | Does |
|---|---|
| `doctor.sh` | Toolchain, repo freshness vs `origin/main`, Accessibility + Screen Recording permissions |
| `build.sh [--skip-tests]` | `swift test`, `xcodebuild` (Debug; `PLAYTEST_CONFIG=Release` for CI parity), ad-hoc sign with the sandbox entitlements, bundled-content check |
| `sim.sh [fighter…]` | Headless FightSim roster runs vs greybox (simulation/content layer only) |
| `launch.sh` | Start the app with stderr captured to `logs/app-latest.log`, wait for the window, bring it to the front |
| `keys.sh STEP…` | Send keyboard input; refuses unless the game is frontmost. Syntax in `PlaytestTool.swift` |
| `shot.sh LABEL` | Screenshot just the game window |
| `logs.sh [10m]` | App stderr, unified log, crash reports |
| `smoke.sh` | Scripted pass: menus → versus match → P1/P2 actions → pause/resume, with numbered screenshots |
| `stop.sh` | Quit the game |

`PlaytestTool.swift` compiles on first use into `build/playtest/bin/playtest`.

The terminal app running these needs **Accessibility** (to send keys) and **Screen & System Audio Recording** (for screenshots). Grant both in System Settings → Privacy & Security; `doctor.sh` checks them.

`AGENT_PROMPT.md` is the prompt for a local Claude Code playtest session.
