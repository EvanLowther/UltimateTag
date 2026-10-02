# Ultimate Tag: guide for AI agents

A simple Roblox tag game with a classic studded look. Code lives in files and syncs into Studio with Rojo.

## Style rules
- **Studded, simple, classic.** Plastic material, bright solid colors, `TopSurface = Studs` / `BottomSurface = Inlet`. No realistic materials, no post-processing, no fancy effects.
- Keep it simple. Prefer one small module per feature over big scripts.

## Layout (Rojo: `default.project.json`)
| Folder | Lands in Studio as | What goes there |
| --- | --- | --- |
| `src/shared/` | `ReplicatedStorage.Shared` | `Config.luau` (all tunables) and modules used by both sides |
| `src/server/` | `ServerScriptService.Server` | `init.server.luau` entry point plus one ModuleScript per service |
| `src/client/` | `StarterPlayerScripts.Client` | `init.client.luau` entry point plus one ModuleScript per UI or feature |
| `src/map/` | `Workspace.Map` | map pieces as `*.model.json` files (one file per part or model) |

## Map
- `src/map/Baseplate.model.json`: 512x4x512 green (75,151,75) studded plastic baseplate, top at Y=0.
- `src/map/SpawnLocation.model.json`: white studded 8x8 spawn pad at the center, no forcefield.
- To add a map piece, add another `*.model.json` in `src/map/`. Use the same studded plastic style.

## Conventions
- Every tunable number or name goes in `src/shared/Config.luau`. Never hard-code it in a service.
- A new feature means a new module, required and started from the matching `init.*.luau`.
- Luau, `--!strict` where practical, formatted with StyLua (tabs, 100 columns).

## Checks (run before every commit)
```
export PATH="$HOME/.rokit/bin:$PATH"
stylua src && selene src && lune run tools/check-syntax.luau && rojo build -o UltimateTag.rbxlx
```

## Workflow
- After each change: update this file (layout, map, features, changelog) and the README if needed, run the checks, commit, then `git push`.
- Commit message format: `area: what changed` (for example `map: add obstacle course`).
- GitHub: https://github.com/EvanLowther/UltimateTag (private). The `.rbxlx` file is built by Rojo and git ignores it.

## Features
**Core tag loop (0.2.0).** Rounds go Waiting -> Intermission -> Playing -> RoundOver. One random player is It and gets a short head-start freeze. It tags a Runner by getting within `Config.Tag.Range`. The tagged player becomes It and is frozen briefly, which also stops instant tag-backs. Whoever is It when time runs out loses, and every Runner gets +1 Win.

| Module | Side | Job |
| --- | --- | --- |
| `shared/Config.luau` | both | All tunables: round times, tag range, speeds, colors, font |
| `shared/GameState.luau` | both | Round `Phase`, `TimeLeft` and `Status` as ReplicatedStorage attributes. Server writes, clients read and listen. |
| `server/Roles.luau` | server | `Role` attribute on each Player (`"It"` / `"Runner"` / nil). Applies speed, freeze and the red It highlight, again on respawn. |
| `server/TagService.luau` | server | Heartbeat distance check from It to Runners. Performs the tag. |
| `server/RoundService.luau` | server | The round state machine, spawn scatter, and win awarding |
| `server/Leaderstats.luau` | server | `Wins` / `Tags` columns in the player list |
| `client/Hud.luau` | client | Status, timer, and the "YOU ARE IT!" / "RUN!" banner |

Rules of thumb:
- Server owns all game state. Clients only read attributes (no RemoteEvents yet; add a `Remotes` setup in `init.server.luau` when one is needed).
- In Studio, a round starts with 1 player (`Config.Round.StudioMinPlayers`). Live servers need `MinPlayers`.

## Changelog
- 0.2.0: Core tag loop: rounds, It/Runner roles, distance tagging, freeze on tag, Wins/Tags leaderstats, HUD.
- 0.1.0: Project setup (Rojo, rokit, StyLua, Selene, Lune). Green studded baseplate and spawn pad.
