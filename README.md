# Arcade Fighter

Original 2D one-on-one arcade fighter for **macOS 14+**, built with native Swift, SpriteKit, and a hexagonal simulation core.

## Layout

| Path | Role |
|------|------|
| `FightCore/` | SwiftPM package — deterministic simulation, content loading, headless `FightSim` |
| `ArcadeFighter.xcodeproj` | Thin macOS app wrapping SpriteKit renderer + local `FightCore` package |
| `Content/` | Fighters, stages, audio (lane-owned subtrees) |
| `Fixtures/Replays/` | Deterministic replay inputs for tests |
| `docs/` | Schema, ownership, builder notes |

## Quick start (core on Linux or macOS)

```bash
cd FightCore
swift build
swift test --parallel
swift run FightSim
```

Requires **Swift 6.1** (see `docs/BUILDER-ENV.md`).

## App (macOS only)

Open `ArcadeFighter.xcodeproj`, select the **ArcadeFighter** scheme, and run. CI builds Release with `CODE_SIGNING_ALLOWED=NO`. The app is fully offline (App Sandbox, no network entitlements).

## Controls (target)

- **P1:** WASD move, F/G/H/J = LP/HP/LK/HK  
- **P2:** Arrows move, numpad 4/5/1/2 = LP/HP/LK/HK  
- **Gamepad:** X/Y/A/B = LP/HP/LK/HK  

Phase 0 shows a minimal greybox render from a `GameSnapshot`; full input and menus arrive in later lanes.

## License

See repository default license (if present).