# Gameplay rules (decided with the owner, 2026-10-30)

The agreed main loop. Where this differs from `AGENTS.md` today, this file is the target; the
work list at the bottom says what changes. Items marked (assumed) were not decided by the owner:
check them when building.

## The loop
1. **Lobby.** At least 2 players start a game. Max 30 players per server.
2. **Countdown.** Starts at 20 s when the 2nd player is waiting. Each player who joins adds 10 s
   to the clock, but the clock never goes above 40 s (past that, joins add nothing and it just
   runs down). Once the lobby has 10 or more players there are no more extensions and the
   remaining time is cut to 15 s at most. Players leaving never add time. Players who join
   during a game wait for the next one.
3. **Rounds** until one player is left (the winner). Format: last one standing, Hot Potato.
4. **Round start.** A new map for the players left (by player count, never the same twice in a
   row). Spawns are a random mix. Everyone is frozen for **5 s** with the role banner shown for
   the first **3 s** only. Its are **not** frozen any longer than everyone else (no head start).
5. **Playing.** Round length by players left: 7 or more: 2:00; 3 to 6: 1:30; 2 left: 1:30 (assumed:
   the owner had no preference between the tier options). Its tag Runners; a tag swaps the roles
   (tagger becomes a Runner, tagged becomes It). **Nobody is ever frozen by a tag** and there is no
   tag-back protection: the knockback is what gives space.
6. **Elimination.** Each round has a target number out (below). Its left at the timer are
   eliminated. The **only** other ways out are falling off the Rooftop District and being hit
   by the Metro's train: **no other map can kill anyone**. Those deaths eliminate at once, count
   toward the target, and the round **ends early the moment the target is reached**. If every It is out or dead mid-round, a new It is picked at random from the
   Runners.
7. **Results (about 5 s).** A card with who was eliminated (and how), how many are left, and
   your own round stats. It doubles as the loading cover: the next map loads and warms up while
   it shows.
8. **Win.** The last player standing wins: the win screen, then back to the lobby and the next
   countdown starts by itself. Wins count in every game size.

## Elimination target (at most 5 rounds)
Roughly a third of the players are eliminated per round, more in big games so a game never
takes more than 5 rounds. Per round: out = max(1/3, 1 - n^(-1/roundsLeft)) of the n players
left, rounded, at least 1 and at most n - 1. Resulting games:

| Start | Players left after each round |
| --- | --- |
| 2 | 1 |
| 4 | 3, 2, 1 |
| 6 | 4, 3, 2, 1 |
| 8 | 5, 3, 2, 1 |
| 12 | 7, 4, 3, 2, 1 |
| 20 | 11, 6, 3, 2, 1 |
| 30 | 15, 8, 4, 2, 1 |

The number of Its at the start of a round equals the target out (so the Its at the timer are
the ones eliminated). A 30-player game is about 5 rounds x (5 s + 2:00 + results) = 11 minutes.
The final 1v1 is a normal round: whoever is It at the end loses.

## Tagging and moving
- Any player can swing (left click), cooldown 0.45 s hit or miss. It's swing tags the nearest
  Runner within 7 studs of the body (no facing needed); every other swing shoves. Every hit
  knocks back. Shoves work in the lobby too.
- Speeds unchanged: Runner 18 (31 sprinting), It 20 (34 sprinting). No stamina.
- The camera is first person only for players (the V toggle is Studio only).

## HUD and screens
- HUD: phase, timer, players left, status line. The big role banner shows only during the first
  3 s of the 5 s freeze and never again that round, even when you tag or are tagged. No small
  role tag afterwards: your role is shown by the red outline (others see it on you, hidden
  behind walls) and, in first person, the red screen tint when you are It.
- Spectating is camera only (see `flow.md`). Spectators just watch. A Leave button takes
  eliminated players back to the lobby early; players still in the game cannot quit.
- AFK: no input for 30 s during a round eliminates you. Leaving the server removes you.

## Later, not now
- Bomb timer mode (a fuse on the It; explodes unless they tag). Other modes, power-ups, round
  modifiers and map events are not wanted ("keep it pure").
- Maps for 13 to 30 players are to be designed from scratch later; until then games over 12
  use the Rooftop District.

## Work list (what this changes)
**Flow agent (wave 2):**
- `Config.Game`: `RoundTime` becomes a function of players left; `LobbyCountdown` 20 with
  `JoinExtend` 10, `CountdownCap` 40, `BigLobby` 10 and `BigLobbyCut` 15; remove `ItHeadStart`;
  intro stays 5 s; remove `Config.Tag.FreezeTime` use (tags freeze nobody).
- `GameLoop`: the countdown rule; the elimination target schedule (`Modes/HotPotato.itCount`
  becomes the schedule above); end the round when the target is reached; a new random It if
  none is left; fall deaths (Rooftop District, `FallEliminates`) and train deaths (Metro)
  eliminate as today and count toward the target (no other map kills anyone, and none needs a
  `KillHeight`); results card with stats while the next map loads; AFK check; Leave button for
  eliminated players.
- `Roles`/`TagService`: no freeze after a tag.
- `Hud`: the role banner only for the first 3 s of the intro; remove the small role tag.
- `ViewMode`: first person only outside Studio.
- Players left / target counters feed the results card.
**Maps agent (small job):** confirm that only the Rooftop District (falling) and the Metro (the
train) can kill, and that no other map has any way to die (no void to fall into, no kill
volumes); add a check so that stays true.
**Economy agent:** nothing new, but rewards must follow the new round counts and game lengths.
**Movement agent:** knockback is the only tag-back defence: its distance matters (see
`movement.md`).

## Not asked / still open
- Exact game length targets beyond the 5-round cap.
- What the results card's round stats are (assumed: your tags, time as Runner, how you fared).
- How `Players.MaxPlayers` (30) is set: it lives in the place file or experience settings, not in
  Rojo.
