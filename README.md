# Ultimate Tag

A simple, classic-looking Roblox tag game. Each round some players are It: left-click to tag someone and pass it on, and don't be It when the timer runs out, or you're out. Rounds move to new maps until one player is left. The code lives in files here and syncs into Roblox Studio with [Rojo](https://rojo.space).

## First-time setup
1. Install [Rokit](https://github.com/rojo-rbx/rokit).
2. Double-click `scripts/setup.command`. It installs the tools and the Rojo Studio plugin, and builds `UltimateTag.rbxlx`.

## Every day
1. Double-click `scripts/start.command`. It opens VS Code and Studio and starts `rojo serve`.
2. In Studio, open **Plugins > Rojo**, set the port to **34874**, and click **Connect**.
3. Edit files in `src/` and they update live in Studio.
4. To play a real game you need at least 2 players: **Test > Clients and Servers**, 2 or more players, **Start**. For movement testing alone, set `Config.Game.Mode = "Sandbox"` in `src/shared/Config.luau` and press Play.

See `AGENTS.md` for the project layout and conventions.
