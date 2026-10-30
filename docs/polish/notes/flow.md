# Flow notes (branch polish/flow)

## Changelog lines (for the overseer to merge into AGENTS.md and bump the version)
- Flow: the tagger highlight is hidden behind walls (`DepthMode` Occluded).
- Flow: out of the game means camera only. Eliminated players stay visible, frozen and flashing red for `Config.Game.EliminatedTime` (1.5 s, the ELIMINATED moment), then their body is parked (anchored, invisible, no collision, 150 studs under the lobby: `Config.Game.ParkOffset`) and they spectate. Falling out of a `FallEliminates` map and joining mid-game park the same way. No more respawn in the lobby while a game is on. New `server/Spectators`.
- Flow: spectating stops the moment the game ends (not after the 8 s Victory phase): everyone is respawned in the lobby at once. Spectators have their controls off and third person forced (`ViewMode.suspend`), and on-screen prev/next buttons next to Q/E (new `client/ControlLock`, reworked `client/Spectate`). Spectators see no role banners.
- Flow: while a game is on, swings and tags from and on anyone not still in it are ignored (`TagService`); parked characters are skipped by the kill height and the train.
- Flow: placements and a podium (`Participants.podium`, later death ranks higher, also within a round; only players still in the server) and a new win screen (`client/WinScreen`, `GameOver` remote replaces `Victory`): a podium stage of up to 3 with the winner's equipped Victory emote, name plates, and each player's own place, coins, XP, crates and items for the game (new `server/GameRewards`). Lasts `Config.Game.VictoryTime`. New `Config.WinScreen`, `Config.Game.PodiumSize`.
- Flow: `Config.Game.DebugLog` (Studio only by default) logs each round's roles, every tag (distance, both speeds), It swings that hit nobody (distance to the nearest Runner), the roles at the timer, eliminations and who is in the game (new `server/GameLog`).

## For the overseer
- Version not bumped, changelog not edited. I updated the AGENTS.md module-table rows for the modules I changed and added rows for the new ones.
- `Progression` is untouched. The win screen's coins/XP come from `server/GameRewards`, which watches `PlayerData.onChanged`: coins and crates are summed from increases, XP is the difference in total XP. Not exact if the player claims a quest/streak from the menu during the game (counted too). If the economy agent changes how profiles store XP/Level (`Progression.xpForLevel` is used), update `GameRewards.totalXP`.
- UI agent: `client/LockerStage.available()` still lets a spectator open the Locker (their parked body is invisible). Suggest adding `and not player:GetAttribute("Spectating")` there. `Spectate` re-locks controls and third person when the preview closes, so nothing breaks, it is only odd.
- Task 8 (lag-compensated tags) not built. The log lines to read: `TAG ... at D studs (range R); speeds ...` and `SWING by It ... nearest Runner: X at D studs`. Misses with D just over R at high speed point at lag.
- The Victory remote was removed from `shared/Remotes` (and its listener in `CosmeticEffects`); nothing else used it.
- Elimination bug: no logic error found by reading. The new guards (non-participants can't tag or be tagged; no instant lobby respawn) remove two suspects; the log will show the rest.

## What the owner should test (2+ clients: Test > Clients and Servers)
1. Highlight: the red It outline is hidden behind a wall.
2. Let the timer run out as It: you stay, freeze, flash red with the ELIMINATED banner for about 1.5 s, then your camera follows another player in third person, WASD does nothing, Q/E, arrows and the two on-screen buttons switch. Your body must not be in the lobby (look at the lobby from another client's spectator view, or check Workspace in a server view).
3. Fall off the Rooftop District: same, the dead body then respawn must end up parked, not in the lobby.
4. A tag from or on a spectator does nothing.
5. Join a third client mid-game: they spectate without a body.
6. Eliminate the second to last and last player: with 2, 3 and 4+ players the win screen shows a podium of 2, 3 and 3, the winner plays their equipped Victory, you get your own place and coins/XP (compare with your coin pill), controls come back after. Spectators get control and a lobby body the moment the game ends, before the screen.
7. Dev panel: skip Results/Victory, switch to Sandbox and back mid-game (nobody left invisible or without controls), Start now.
8. Output window: read the `[Game R...]` lines and send them if an elimination looks wrong.

## Unverified (could not run the game)
Everything. In particular: the camera and control hand-back at the game's end (a few frames of the old camera while the new character spawns), the win screen layout on small screens, copies of other players' characters on the podium (idle animation falls back to your own Animate script's), the red flash, and whether anything else teleports or unanchors a parked character.
