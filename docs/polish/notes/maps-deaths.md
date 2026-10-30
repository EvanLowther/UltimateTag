# Maps notes: ways to die (branch polish/maps-deaths)

The rule (`gameplay-rules.md`): only the Rooftop District (falling off) and the Metro (being hit
by the train) can kill or eliminate anyone. Nothing here was playtested; everything below comes
from reading the generators, the map attributes and the server code, plus the checks.

## Changelog lines (for the overseer)
- Maps: `tools/mapcheck.py` has two new checks. `deaths`: a map other than the Rooftop District and
  the Metro with a `KillHeight` or `FallEliminates` attribute fails. `escapes`: on every map without
  a `KillHeight` (all but those two), nothing reachable may have open void beside it, or level
  out-of-bounds ground, and no launch pad may throw you out of the map. Runs for every map in
  rotation, the lobby and every generator.
- Maps: `mapcheck`'s long-jump edges now sample the path every 0.5 studs (was every 1.5 to 2.2), so a
  jump can no longer "pass through" a 2-thick wall between two samples. It had made a few
  spots outside the Clocktower's tower wall look reachable. No map's reach result changed.

## Every way to die (all code that can kill: `server/MapRespawn` and `server/Trains` only)
The only writers of `Humanoid.Health = 0` are MapRespawn (below `KillHeight`, only on the loaded
map within `Config.Game.KillRadius` 1000 of it) and Trains (hit by the Metro's train). Nothing
else damages anyone (no `TakeDamage`, no kill bricks, no `Touched` hazards, no `Slip` use).
`Workspace.FallenPartsDestroyHeight` is the Roblox default (-500; not set in the project).

| Map | Ways to die | Verdict |
| --- | --- | --- |
| Lobby (Night Market) | None. Enclosed by buildings 40 to 90 tall; its ground (1790..2240 by -170..200) is under everything. The Training Alley launch pad (-2.1, 69, -43.2) lands on its platform (16.4). Parked spectators sit 150 under it (Y -150, anchored), above -500. | OK |
| School | None. No `KillHeight`/`FallEliminates`, one solid Ground under the whole footprint, a Roof over it. The springboard (0, 95, -12) rises to the gym roof (its apex, about 34.6, meets the roof underside at 34) and bonks: it cannot leave the building. Puddles are decoration. | OK |
| Clocktower | None. One solid 84 x 84 Floor under the pit and Works, a Ceiling (58 to 62) over the tower. The pendulum has no `Knockback` and is a carried platform; gears and the crown wheel are platforms you ride; dropping off them lands on the floor, gallery or deck. | OK |
| Playroom | None. Walls (`SkyWall`) and ceiling enclose the 96 x 96 room, one floor. The spinner bar's `Knockback` 30 pushes along the floor (walls stop it, a hit cannot lift anyone over a ceiling at 40). The jack's throw (23, 70, -17) lands on the gatehouse (12). | OK |
| Tag Mart | None. One floor, walls and ceiling all round, nothing launches. Belt `SpeedBoost` only adds ground speed. | OK |
| Rooftop District | Falling below Y 30 (`KillHeight` 30) with `FallEliminates`: out of the game when it happens in the Playing phase. Nothing else kills (the launch vents throw you onto roofs; the swinging platform and wall runs do not hurt). | By design: the only fall death |
| Metro | The train: anyone not aboard in its way while it moves, from the pit bottom to its roof (server/Trains). Also `KillHeight` -25 (see below). Nothing else. | By design: the train |
| TestGround (not in rotation) | Sandbox only: walking off the 512 x 512 baseplate drops into the void and Roblox destroys the character at -500. Dev map, not played in games. | Out of scope |

## Escape check results (the new `escapes` check, plus reading)
- No real escape found in the School, Clocktower, Playroom, Tag Mart or the Lobby: no reachable spot
  has void beside it, and none of the launch pads (School springboard, Playroom jack, lobby pad)
  ends in the void in the simulation. Nothing in the generators needed changing.
- I mutation-tested the check: removing one wall piece from the Playroom, Tag Mart, School and
  Clocktower each made it fail with the right place; a `KillHeight` on the School fails `deaths`.
  The current maps give zero alarms.
- Not covered (unverified, needs a playtest): getting onto a wall top by wall running and wall
  jumping (a chain climbs at most `ChainMaxRise` 9, then a jump), and any move the check cannot
  model. By reading: the School, Clocktower, Playroom and Tag Mart all have a ceiling or roof over
  the whole footprint with walls reaching it, and the lobby's buildings are 40 or more tall, so
  there is no wall top to run onto. The lobby's `OuterGround` is out of bounds and the check also
  flags stepping onto level out-of-bounds ground, so a gap in the lobby's buildings would show.

## Metro: the `KillHeight` -25 and the tunnels
- On foot, the tunnels cannot be reached. The four mouths (x = +-120, over each track pit, z +-18 to
  +-40.5, from the pit floor to the portal top 15.9) are filled by `TrainBarrier` parts, solid for
  everyone but the train's riders (client/Trains). The barrier covers the whole mouth width and
  the height up to the portal top, and the platform (|z| < 18) does not touch the mouths. So the
  only people in the tunnels are riders on the train.
- Below the mouths there is a solid tunnel bed only for the first 9 studs (Y -6 to -4); past that
  the loops have no floor, and `KillHeight` -25 is what catches anyone who is there without the
  train. The track pits are 4 deep (Y -4), far above -25.
- **Recommendation: keep `KillHeight` -25 on the Metro as a safety net.** Reaching it on foot is
  not possible, so it costs nothing in normal play. If something did put someone there (a rider
  desync while the train is in a tunnel, a push past a barrier, a tunnel glitch) the alternative is
  not "no death": they would fall about 475 studs to Roblox's -500 and be destroyed after several
  seconds, which still counts as a death. The kill height just makes that fast and clean. It is
  also counted as a fall elimination (the message says "fell and is out", not "hit by the train"),
  which the owner has not asked for but which only matters if the unlikely thing happens. If the
  owner wants the message to match, a later change could report any Metro death as the train.

## What the owner should test
1. Walk the Metro's platform ends and try to jump or slide into each tunnel mouth (four of them):
   you should be blocked by the invisible barrier; try with and without the train in.
2. In the School, Clocktower, Playroom and Tag Mart, try to leave the map by wall running and wall
   jumping along the outer walls (especially corners and the Clocktower's tower wall), and try the
   School springboard, the Playroom jack and the Playroom spinner: you should always stay inside.
3. Try to find any way to die on those maps (none should exist).
