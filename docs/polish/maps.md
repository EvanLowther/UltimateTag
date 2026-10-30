# Maps: floating objects, clipping, art

Owner: maps agent. Touches `tools/maplib.py`, `tools/mapcheck.py`, every `tools/*_layout.py`,
`src/maps`, `src/lobby`, `Config.MapLighting`. Never hand-edit generated map folders; change
the generator and rerun it.

## What is wrong now
- `tools/mapcheck.py` covers: tiny or inside-out parts, faces sharing a plane (flicker), overlays
  laid too close, nothing cutting into window glass, ladder trusses sunk into something, and
  reach (every area reachable from the spawns and a way back).
- It does **not** catch what the owner reports: props with nothing under or behind them,
  solid parts pushing through walls or floors, pockets a player can get stuck in, and tops
  a player can jump or wall-run onto outside the play area.
- Sizes: Lobby 4,281 parts, Metro 2,141, Clocktower 1,639, School 1,018, Rooftop District 867,
  Tag Mart 497, Playroom 122. Performance on low-end devices has not been measured. Whether
  the place file has streaming on is unknown (it is not in the project file); ask the owner.
- Known untuned values: School springboard (`LaunchVelocity` 0, 95, -12), Tag Mart belt
  `SpeedBoost` 40, Playroom lip `SpeedBoost` 50 and the jack's throw, the lobby's neon level, the
  Training Alley dummies (props: swings do nothing to them).

## Tasks, in order
1. **New checks in `mapcheck.py`** (each with a limit and a clear message like the existing ones):
   - `floating`: a visible, collidable, non-detail part that touches nothing (gap over 0.05 to
     every other part) and is not a deliberate hanging prop (an attribute `Hangs` for those).
   - `intersections`: pairs of solid parts that penetrate by more than 0.3 where neither is
     meant to be a child of the other (props through walls, furniture through floors); ignore
     walls meeting walls.
   - `pockets`: sample the walkable space on a grid; flag spots where a character-sized volume
     fits but the only way out is narrower than the character, or a dead end under 2 studs wide.
   - `escapes`: walkable tops that a jump or a wall run (from the existing reach routes) can get
     onto but that are not in the map's `OutOfBounds`.
   Tune thresholds on the current maps until false alarms are rare, then list real findings.
2. **Run them on all seven** and write `docs/polish/notes/maps-findings.md`: per map, what each
   check found and whether it is real.
3. **Fix real findings in the generators** (move, resize, add supports, or mark `Hangs`), rerun
   the generators and the checks. Do this per map, one commit each.
4. **Performance pass.** Count parts per map and per kind (detail versus solid); merge tiny
   decorative parts where nothing is lost; consider `CollisionFidelity` and `CanQuery` for detail;
   report heavy spots.
5. **Art pass per map** (wave 2, after movement settles): lighting, material variety, signage,
   trim, prop density, readability of routes. One checklist per map in the notes file; the owner
   reviews each in game and gives notes. Include the untuned values above in each map's list.
6. **Training Alley dummies**: make the three dummies react to swings (a small shared prop script,
   client-side, using `TagSwingPlayed`).

## Dependencies
Movement changes (jump range, wall jump, landing) change what is reachable. `mapcheck`'s jump
constants (`JUMP_SPEED`, `RUN`, `GRAVITY`, `JUMP_MARGIN`) must follow `Config`; retune gaps (the
Rooftop District's 18 to 22 wall-run alleys, the Metro's 18 stud works gap) only after movement
lands.

## Decisions for the owner
- Streaming on or off in the place file.
- Which maps get the art pass first.
- How strict the new checks may be (stuck pockets are subjective).

## What the owner tests
Walk each map hunting for the things the checks found; report anything the checks missed so
it becomes a check.

## Done when
All seven pass the new checks (or have a documented exception), and the findings notes show no
open real issue.
