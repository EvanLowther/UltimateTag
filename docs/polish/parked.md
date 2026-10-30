# Parked and later

## Waiting
- **Sound design** (including UI). Decided: Roblox library sounds first. Plan when it starts: a
  `client/Sfx` module with a `Config.Sounds` table of ids by event (UI click, hover, purchase,
  level up, crate reel; swing, hit, tag; slide, wall run, jump, land, launch; countdown, round
  start, elimination, win; train and doors; ambient loops per map, lobby rain; music).

## Not a priority now (the owner's list)
- Paid items, Robux to Coins, donation option, VIP. `server/Purchases.luau` exists and is
  switched off (no ids in `Config.Monetization`).

## Later
- **Anti-exploit.** Movement is client-authoritative and the server trusts `MoveDone` (quests and
  the wall-run board can be farmed). Add server sanity checks before any competitive rewards.
- **Tests.** Only syntax, style and map checks exist. Add Lune tests for pure logic
  (`TrainLine`, `Progression` math, `Participants` placements, the economy simulator).
- **Docs drift.** Keep `AGENTS.md` and the README in step as plans land.
- **Old assets.** The island's Blender source and `src/tools/LobbyData.luau` are unused.
- **More modes.** Hot Potato is the only game mode.
