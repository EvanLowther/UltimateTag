# Polish plan

The game needs a lot of polish. This folder has one plan per area. Each plan says what is wrong
(checked against the code on 2026-10-29), what to do in order, which decisions need the owner,
and what the owner should test (agents cannot playtest). The owner's original list is kept in
`parked.md` when an item is not scheduled.

| Plan | Area | Wave |
| --- | --- | --- |
| [flow.md](flow.md) | Rounds, elimination, spectating, win screen, tagger highlight | 1 |
| [ui.md](ui.md) | Locker preview and small screens, menus, touch | 1 |
| [maps.md](maps.md) | New map checks, floating and clipping fixes, art passes | 1 (checks), 2 (art) |
| [economy.md](economy.md) | Rewards, pricing, XP/coin consistency, redeem codes | 1 (sim, decisions), 2 (rebalance) |
| [movement.md](movement.md) | Wall-run chains, landing, momentum model, animations | design talk first, code in 2 |
| [victories.md](victories.md) | The new victory animations (win screen and Locker) | ideas, then previews, then build |
| [parked.md](parked.md) | Sound (waiting), payments, anti-exploit, tests, dead code | later |

## Rules for every agent
- Work in your own git worktree on its own branch:
  `git worktree add ../UltimateTag-<area> -b polish/<area>`. Never work in the shared checkout.
- Do not bump `Config.Version` or edit the changelog in `AGENTS.md`. Write your changelog lines
  in `docs/polish/notes/<area>.md` (create it) and the overseer merges them and bumps the version.
- Run the checks before every commit (see `AGENTS.md`): stylua, selene, check-syntax, mapcheck,
  `rojo build -o build/check.rbxlx`. Never build to `UltimateTag.rbxlx`.
- Commit with explicit paths only, `area: what changed`, no co-author or AI lines.
- Nobody playtests. Finish each task with a short "what to test" list for the owner.
- Anything that changes a number or behaviour owned by another area (see "Touches" in each plan)
  goes to the overseer first.
- Use the project's helpers (`Ui`, `maplib`, `Config`) and every tunable goes in `Config.luau`.

## Order of merging
flow, then ui, then economy, then the map checks, then movement, then the map art passes. Movement
changes how far every jump reaches, so map gaps and `tools/mapcheck.py`'s jump constants are only
retuned after movement settles.

## Who touches what
| File or area | flow | ui | maps | economy | movement |
| --- | --- | --- | --- | --- | --- |
| `server/GameLoop`, `Participants`, `Roles`, `TagService`, `MapRespawn` | owns | | | | |
| `client/Spectate`, `Hud`, new `WinScreen` | owns | | | | |
| `client/Menu/*`, `LockerStage`, `Ui` | | owns | | RewardsTab only | |
| `tools/*_layout.py`, `maplib`, `mapcheck`, `src/maps`, `src/lobby` | | | owns | | reads constants |
| `server/Progression`, `PlayerData`, `Shop`, `Config.Progression/Shop` | reads | | | owns | |
| `client/` movement modules, `Config` movement tables | | | | | owns |
| `shared/Config.luau` | shared: add your own table or keys, do not reformat other areas' |

## Decisions already made (2026-10-29)
- Eliminated players are camera-only spectators: no lobby respawn, body parked out of sight, everyone
  back in the lobby when the game ends.
- Win screen: podium of 3 (winner and the last two eliminated), the winner's equipped Victory emote,
  and each player's own coins and XP for the game.
- Spectating ends the moment the game ends (today it lasts through the 8 second Victory phase).
- Redeem codes are wanted. Sounds wait. Payments, donations and paid items are not a priority.
