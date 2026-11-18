# Path ownership

Changes outside your lane require a separate contract PR merged by Russell.

| Path | Owner |
|------|--------|
| `.github/` | Russell only |
| `FightCore/Package.swift` | Phase 0 (frozen) |
| `FightCore/Sources/FightCore/Contracts/` | Phase 0 (frozen) |
| `FightCore/Sources/FightCore/Sim/` | Phase 0 (frozen) |
| `FightCore/Sources/FightCore/Data/` | Phase 0 (frozen) |
| `FightCore/Sources/FightCore/Input/` + `Tests/FightCoreTests/Input/` | L1 |
| `FightCore/Sources/FightCore/Fighter/` + `Tests/FightCoreTests/Fighter/` | L2 |
| `FightCore/Sources/FightCore/Collision/` + `Tests/FightCoreTests/Collision/` | L3 |
| `FightCore/Sources/FightCore/Match/` + `Tests/FightCoreTests/Match/` | L4 |
| `FightCore/Sources/FightCore/AI/`, `FightCore/Sources/FightSim/` + `Tests/FightCoreTests/AI/` | L5 |
| `FightCore/Sources/AppLogic/Render/` + `Tests/AppLogicTests/Render/`, `App/Render/` | L6 |
| `FightCore/Sources/AppLogic/Menus/` + `Tests/AppLogicTests/Menus/`, `App/Shell/` | L7 |
| `FightCore/Sources/AppLogic/InputMap/` + `Tests/AppLogicTests/InputMap/`, `App/Input/` | L8 |
| `Content/Fighters/kestrel/`, `Content/Fighters/bruno/`, `Content/Stages/stage1/`, `Tests/ContentTests/L9/` | L9 |
| `Content/Fighters/ilse/`, `Content/Fighters/rook/`, `Content/Stages/stage2/`, `Content/Audio/`, `App/Audio/`, `Tests/ContentTests/L10/` | L10 |
| `Content/Fighters/greybox/`, `Fixtures/Replays/`, `Tests/FightCoreTests/Contracts/` | Phase 0 |
| Expected-hashes file under `Tests/FightCoreTests/Contracts/` | Phase 2 |
| `ArcadeFighter.xcodeproj/`, `App/ArcadeFighter.entitlements`, `App/Info.plist`, `App/AppMain.swift` | Phase 0 (frozen) |
| `docs/` | Phase 0; lanes may add `docs/lanes/LNN.md` only |
| `Tests/IntegrationTests/`, balance reports | Phase 2 |