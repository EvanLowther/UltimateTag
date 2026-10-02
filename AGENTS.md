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
- `src/map/TestCourse.model.json`: movement test course heading -Z from spawn. Five yellow steps up to three raised platforms (blue, red, green; top at Y=10). The gap after the blue one is 6 studs (walk jump), the gap after the red one is 11 studs (needs a sprint jump).
- `src/map/SlideBar.model.json`: red bar on two yellow posts at X=30, Z=-20 (underside at Y=4.2). Too low to walk under, so you have to slide. The posts are 22 studs apart; run at it from +Z. An invisible `StandBlocker` part fills the space under the bar (attribute `SlideBlocker`), because a character's collision box doesn't reach its head. Sliding characters pass through it.
- Any part with the `SlideBlocker` attribute blocks standing players but not sliding ones. Use it for every slide-under obstacle.
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
**Sandbox (0.3.0).** No rounds, timer or wins yet. This is a free-play test mode for building mechanics. Everyone is a Runner and one player is always It. It tags a Runner by getting within `Config.Tag.Range`. The tagged player becomes It and is frozen briefly, which also stops instant tag-backs. If It leaves, someone else becomes It. Test with two or more players (Studio: Test tab > Clients and Servers > Local Server).

| Module | Side | Job |
| --- | --- | --- |
| `shared/Config.luau` | both | All tunables: tag range, freeze time, speeds, colors, font |
| `shared/GameState.luau` | both | Status text as a ReplicatedStorage attribute. Server writes, clients read and listen. |
| `server/Roles.luau` | server | `Role` attribute on each Player (`"It"` / `"Runner"` / nil). Applies speed, freeze and the red It highlight, again on respawn. |
| `server/TagService.luau` | server | Heartbeat distance check from It to Runners. Performs the tag. |
| `server/Sandbox.luau` | server | Free-play setup: players join as Runners, keeps one player as It |
| `server/CollisionGroups.luau` | server | Registers the `SlideBlocker` / `Sliding` collision groups and puts `SlideBlocker` parts in their group |
| `server/Leaderstats.luau` | server | `Wins` / `Tags` columns in the player list (Wins unused until rounds return) |
| `client/Sprint.luau` | client | Hold `Config.Sprint.Key` (Left Shift) to run `Config.Sprint.Multiplier` times faster, with a small field-of-view boost. Client-side for instant feel. |
| `client/Slide.luau` | client | Press `Config.Slide.Key` (C) while sprinting on the ground to slide. Keeps momentum, fades to walk speed, lowers the character, can't stand up under a low ceiling, jump out keeps speed. |
| `client/SlidePose.luau` | client | The slide animation: rotates R15 joints to the pose in `Config.Slide.Pose`, blended over the run animation, plus hip sink and camera dip. Client-only, so other players don't see it yet. |
| `client/Hud.luau` | client | Status text and the "YOU ARE IT!" / "RUN!" banner |

Rules of thumb:
- Server owns all game state. Clients only read attributes (no RemoteEvents yet; add a `Remotes` setup in `init.server.luau` when one is needed).
- Rounds were removed in 0.3.0 (see git history, `RoundService.luau` in 0.2.0) and will come back once the mechanics are settled.

## Changelog
- 0.5.1: Slide animation (code-driven R15 pose, no clipping into the ground). Slide bar now blocks standing players with an invisible blocker that sliders pass through.
- 0.5.0: Slide (C while sprinting) and a SlideBar test obstacle.
- 0.4.0: Movement work: Sprint (hold Shift) and a TestCourse map for jump tests.
- 0.3.0: Removed rounds, timer and spawn scatter. Added Sandbox free-play mode for testing mechanics.
- 0.2.1: Rojo serve port changed to 34874 (34872 was clashing with another project).
- 0.2.0: Core tag loop: rounds, It/Runner roles, distance tagging, freeze on tag, Wins/Tags leaderstats, HUD.
- 0.1.0: Project setup (Rojo, rokit, StyLua, Selene, Lune). Green studded baseplate and spawn pad.
