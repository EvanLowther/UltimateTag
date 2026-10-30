# Flow: rounds, elimination, spectating, win screen

Owner: flow agent. Touches `server/GameLoop`, `Participants`, `Roles`, `TagService`,
`MapRespawn`, `client/Spectate`, `Hud`, a new `client/WinScreen`, `shared/Remotes`.
Reads `server/Progression` (economy owns it; ask before changing it).

## What is wrong now
- **Tagger highlight shows through walls.** `server/Roles.luau` makes the `Highlight` without a
  `DepthMode`, so it draws on top of everything.
- **Eliminated players are respawned in the lobby at once** (`sendToLobby` in `GameLoop`, and
  the death respawn in `MapRespawn`). Their lobby character stays live while the camera
  watches a map 2000 studs away; `client/Spectate` never locks controls or tells `ViewMode`.
  They also vanish before the results are shown.
- **Spectating outlasts the game.** `Spectate.GAME_PHASES` includes `Victory` (8 s), so spectators
  keep watching until the lobby phase instead of getting their own view back.
- **Elimination bug (reported: wrong player out, and players not removed).** No logic error found
  in the round code (tagging swaps It, so the count is constant). Suspects: tags decided by the
  server's lagged positions (a swing hits on your screen, not on the server); the instant
  respawn; `TagService.nearest` ignores `InGame`/`Alive` (any player in range counts).
- **No placements.** `Participants` does not record elimination order, so there is nothing to
  build a podium from.
- **Win flow today:** a "<name> wins!" banner plus the winner's emote in the lobby for
  `VictoryTime` (8 s). Everyone else just stands in the lobby.

## Tasks, in order
1. **Highlight.** `DepthMode = Enum.HighlightDepthMode.Occluded` in `Roles.apply`. (Trivial; can
   ship alone.)
2. **Logging.** Behind `Config.Game.DebugLog` (default on in Studio only): print each round's
   roles at the start, every tag (tagger, tagged, distance, both speeds), the roles at the timer,
   who is eliminated and why, and each `Participants` change. One playtest then shows the
   elimination bug. Ask the owner to send the output.
3. **Eliminated = camera only.**
   - Replace `sendToLobby` for eliminated players with a "park": anchored, invisible, no collide,
     parked at a spot under the lobby (not a kill height), `Spectating` attribute set. Fell-out
     players (they die) get the same after their respawn, never a map or lobby spawn.
   - `TagService.nearest` and the map hazards ignore anyone without `InGame` and `Alive`
     during a game.
   - At the game's end, respawn everyone in the lobby plaza (`LoadCharacter`), one place only.
4. **Spectate rework.** Only in `Intro`, `Playing`, `Results` and only for players not alive; lock
   controls and call `ViewMode.suspend(true)` while spectating; give everything back the moment
   the game ends (before `Victory`). Add on-screen prev/next buttons (touch) next to Q/E and
   arrows; hide the spectator's own HUD role banners.
5. **Placements.** `Participants.eliminate` records `{player, round, order}`; add
   `Participants.podium()` returning the winner plus the last two eliminated (same-round ties:
   later time of death ranks higher; say so in code). Handle 2 and 3 player games (shorter
   podium) and a winner who left (next best).
6. **Win screen** (`client/WinScreen`, new). Server sends one `GameOver` remote when the game
   ends: `{podium = {...}}` to all, and each player's own `{coins, xp, items}` for the game to
   that player (Progression needs per-game totals: ask economy). Client builds a small stage
   locally (reuse the approach in `client/LockerStage`: character copies, scripted camera,
   `CosmeticEffects.playVictory` for the winner), shows the podium with names and place numbers,
   then the player's rewards in the `Ui` style. Duration: `Config.Game.VictoryTime`; allow
   the owner to change it. Movement and HUD hidden while it plays; controls back after.
7. **Results timing.** Show who was eliminated while they are still visible: a short "ELIMINATED"
   moment (freeze, effect, camera still on them) before the park.
8. **Tag fairness** (only if the logs point at lag). Server-side hit check against a short
   position history (rewind by the swinger's ping, capped) instead of current positions; make
   `Config.Tag` carry the cap. Needs an owner decision (see below).

## Decisions for the owner
- Podium tie-break rule (default: later death ranks higher).
- Win screen length (default: keep 8 s; maybe 10).
- Whether to add lag compensation to tagging (after the logs).

## What the owner tests
Two or more clients in Studio (Test > Clients and Servers): tag, time out, fall off the Rooftop
District, eliminate the second to last player and the last; check the highlight through a wall,
the spectator view and controls, getting your own character back the moment the game ends, the
win screen with 2, 3 and 4+ players, and the logged output.

## Done when
All of the above works for 2 to 8 players, `Spectating` leaves no live body in the lobby, and the
logging shows no wrong eliminations in a full game.
