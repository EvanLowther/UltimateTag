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
- (none yet: just the map)

## Changelog
- 0.1.0: Project setup (Rojo, rokit, StyLua, Selene, Lune). Green studded baseplate and spawn pad.
