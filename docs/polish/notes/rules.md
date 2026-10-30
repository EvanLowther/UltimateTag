# Rules notes (branch polish/rules)

The flow agent's wave 2: the agreed game rules from `docs/polish/gameplay-rules.md`.

## Changelog lines (for the overseer to merge into AGENTS.md and bump the version)
- Rules: lobby countdown follows the agreed rule: 20 s when the 2nd player is waiting, +10 s for each player who joins, never above 40 s, no extensions and at most 15 s left once 10 players wait, leavers never add time (`Config.Game.LobbyCountdown`, `JoinExtend`, `CountdownCap`, `BigLobby`, `BigLobbyCut`; pure functions in new `shared/RoundPlan`). Dev panel Skip, Start now and Time left still work.
- Rules: round length depends on players left (`Config.Game.RoundTimes`: 7 or more 2:00, fewer 1:30; the dev panel's round length is now an override, `RoundTimeOverride`). The intro is 5 s for everyone: `ItHeadStart` is gone. Tags freeze nobody (`Config.Tag.FreezeTime` is gone) and there is no tag-back protection.
- Rules: every round has an elimination target so a game takes at most 5 rounds (`RoundPlan.eliminateTarget`, schedule table in its comment, `Config.Game.MaxRounds`; `lune run tools/roundplan-test.luau` prints it for 2 to 30 players and asserts the cap). The number of Its equals the target (`HotPotato.itCount` and `EliminateFraction` are gone). The round ends the moment the target are out (timeout, fall on the Rooftop District, the Metro's train, AFK, players leaving all count); at the timer only as many Its as the target has left are eliminated (the ones who held it longest first). If every It is out or dead, a random Runner becomes It. Game modes' `canContinue` is gone; `setup(players, target)` and `finish(players, quota)`.
- Rules: the big role banner shows once per round, during the first `RoleBannerTime` (3 s) of the 5 s intro; the small role tag is gone. First person only in live servers (the V toggle and `StartFirstPerson` are Studio only).
- Rules: Results is a card (`client/RoundResults`, `RoundResults` remote): who went out and how (still It, fell, the train, AFK), players left, your tags and time as It. It is the loading cover: after `Config.Game.ResultsCoverAt` (1.8 s) a dark backdrop hides the world, the old map is unloaded, the next one is loaded and everyone placed on it (`GameLoop.loadRound`), the new map is preloaded on each client, and the cover goes when the intro starts. Round 1 (from the lobby) has no cover. New `server/RoundStats`.
- Rules: AFK: 30 s (`Config.Afk`) of no input and no movement during the round timer eliminates you (not in the intro, not for players already out). The client pings the new `Activity` remote (`client/Activity`); the server also counts body movement (`server/Afk`).
- Rules: eliminated players get a Leave button on the spectate bar (`LeaveGame` remote, `Spectators.leaveEarly`): they respawn in the lobby at once, stay out of the game (`LeftEarly` attribute) and can shove there. Players still in the game cannot quit.

## Decisions I made where the spec was open
- Lobby countdown start: always `LobbyCountdown` (20) when it starts, cut to 15 if 10+ are already waiting. Players already in the lobby (everyone back after a game) are not counted as "joins".
- The big-lobby cut happens once per countdown, so the dev panel's Time left can set a longer time afterwards.
- A Runner who falls or is hit by the train while the Its stay the same size leaves more Its than the target has room for at the timer. Then only the Its who have held it longest go out (total out = target), not everyone who is It.
- Players who leave count as "out" for the target (so a leaver in a 3-player round ends it).
- Results stats: your tags, time as It, how you fared (safe, out and why, watching). "Times tagged" is counted (`RoundStats`) but not shown.
- The role banner uses `TimeLeft` of the intro to decide the 3 s window, so it shows only if the client sees the intro start (it does not show again if you join the server mid-intro).

## For the overseer
- Version and changelog not touched. AGENTS.md: I updated the game flow paragraph, the game modes line and the module-table rows I changed, and added rows for `RoundPlan`, `RoundStats`, `Afk`, `Activity` and `RoundResults`.
- `Progression` untouched. `GameRewards` untouched.
- `client/DevPanel/GameTab.luau` and `server/DevCommands.luau`: the "Round length" box now sets `Config.Game.RoundTimeOverride` (the old `RoundTime` key is gone). The box's starting number is a fixed 120 (the dev panel is not told the real value).
- `Players.MaxPlayers` (30) still lives in the place settings.

## What the owner should test (2+ clients: Test > Clients and Servers; one with a friend or test accounts for the AFK)
1. Lobby: with 2 players the countdown starts at 20; a third client joining adds 10; joins never push it past 40; a client leaving does not add time. (10 clients are hard to test: read the GameLog line `lobby countdown ...`.) Dev panel Skip, Start now and Time left still work.
2. A 2-player game: one round, whoever is It at 1:30 loses and the other wins. A 3-player game: 2, then 1.
3. Intro: everyone frozen 5 s (the It too), the big banner (YOU'RE IT! or RUN!) shows for about 3 s and does not come back when you tag or are tagged. No small tag under the top bar. Tagging someone does not freeze them.
4. Round end: let the timer run out; the Its (up to the target) are eliminated, then the results card with the list, "N players left" and your numbers. About 1.8 s later the screen goes dark, the next round's map appears under it, and the card goes when the next intro starts. Nobody should see the old map vanish or the new one half built, and nobody should fall through the world.
5. Early end: on the Rooftop District fall off (or on the Metro get hit by the train) until the target is reached: the round should end at once, and the card should list "FELL" or "THE TRAIN".
6. If you are the only It and you fall/leave: a random Runner becomes It (check the status line and the log).
7. AFK: stand still, no mouse or keys, for 30 s in the Playing phase: you are eliminated (ELIMINATED moment, then spectating). Not during the intro.
8. Leave button: as an eliminated player click Leave on the spectate bar: you appear in the lobby, controls back, no second parking; you can still shove people there. Players still in the game have no such button.
9. In a live server (or by setting `RunService:IsStudio()` thinking): first person only, V does nothing. In Studio V still toggles.
10. Sandbox mode and the dev panel mode switch mid-round, mid-results and mid-countdown leave nobody frozen, covered or invisible.
11. Output window: the `[Game R...]` lines now include `round N ... to go out`, `no It left`, `out mid-round`, `has been AFK`, `lobby countdown`.

## Unverified (could not run the game; nothing here was played)
Everything runs only as far as stylua, selene, the syntax check, mapcheck and `rojo build` go; there is no Luau type checker here, so strict-mode type warnings in Studio are possible. In particular: the Results cover timing and the map swap under it (placement and the 0.5 s settle), the preload of the new map, AFK ping coverage on touch and gamepad, `RoundResults` layout at small sizes (it has its own UIScale, not the menu's), the Leave flow (the camera hand-back), the round-ending race when two players fall in one frame, and the lobby countdown extension while players join.
