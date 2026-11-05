---
paths:
  - "src/client/**"
  - "src/shared/TitleTag.luau"
  - "src/shared/CosmeticLook.luau"
---
# UI style

Moved out of AGENTS.md. Read it before working on any file listed in `paths` above.

- **UI** (every menu, popup and HUD piece) uses the "Street sprint" style in `client/Menu/Ui.luau`: flat black panels with cut corners (`Ui.panel`), slanted bars, tabs and buttons (`Ui.slab`, `Ui.button`, `Ui.tabs`), hazard yellow, hot pink, cyan and lime, Bangers headlines (`Ui.title`) over heavy Titillium Web capitals (`Ui.caps`), slanted progress bars and XP segments, rarity strips (`Ui.rarityStrip`; Iridescent shimmers with `Ui.holo`), a coin pill and a column of slanted page buttons on the left, the level bar at the bottom center. Each window has its own header color (Shop yellow, Locker cyan, Quests pink, Rewards lime, Leaders orange). Build new UI from these helpers, not raw instances. (The dev panel keeps its own plain look.) **No emoji anywhere** (menus, HUD or world effects): icons are drawn in code by `client/Icons` (`Ui.icon`, `Ui.centerIcon`, `Ui.iconText`, a button's `icon`; in BillboardGuis `Icons.draw`), from flat shapes in a main color and an accent. A new icon is a new entry in its `DRAW` table, built from its shape helpers. Text sizes go through `Ui.readable` (in `Ui.text`, so `Ui.caps`/`Ui.title`, and in `Ui.shrinkText`, `Ui.setTextSize`, `Ui.tabs`): anything under 24 is drawn bigger (11 becomes 16, 13 18, 16 20, 20 23) and nothing shrinks below `Config.Ui.MinTextSize` (15), so write the design size and give the box room for the raised one; never feed `Ui.readable`'s result back into those helpers. Gotchas: upper-case with `Ui.upper`, never `string.upper` (it mangles accented names in Roblox); a frame with AutomaticSize can't hold Scale-sized children such as a slab's pieces (they stretch it to fill its parent), so size it with `Ui.fitWidth`; keep an icon's frame square (its shapes are sized against both sides, so turned shapes skew in a wide frame); give icons on the dark wells a light accent (a dark one vanishes).
