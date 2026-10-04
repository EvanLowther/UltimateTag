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

## Setting up the lobby (once)
The lobby island isn't in the code files: it lives in your place file, so you can move things around in Studio.
1. In Studio: **Home > Import 3D**, pick `assets_src/lobby/UltimateTagLobby.fbx`, click **Import**.
2. Open **View > Command Bar** and run: `require(game.ServerStorage.Tools.SetupLobby)()`
3. Save the place (**Ctrl+S**), and publish it to Roblox to keep it safe.
After that, click any tree, bench or building in `Workspace > Lobby` to move, rotate or duplicate it. Save the place when you're done.

For saved wins and the global leaderboard, publish the place and turn on **Game Settings > Security > Enable Studio Access to API Services**.

See `AGENTS.md` for the project layout and conventions.
