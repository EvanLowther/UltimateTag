# UI audit notes (branch `polish/ui-audit`)

Nothing here was run in Studio: only stylua, selene, check-syntax, mapcheck and `rojo build` were
run, and there is no Luau type checker in this environment. Every number below was worked out
from the code, not seen. The auditor exists so the owner can get real numbers at any window
size; run it and send the output back.

## Changelog lines (for the overseer to merge into AGENTS.md and bump the version)
- UI audit: new dev panel tool `client/DevPanel/UiAudit` (Debug tab, "UI audit"): "Scan the UI
  now" and "Open every window with worst-case content, then scan". Checks every visible text in
  every ScreenGui except the dev panel for text that does not fit (FIT), is cut off (CUT), is
  closer than `Config.Ui.MinPadding` (8 px sideways) / `MinPaddingY` (4 px above and below) to the
  edge of the box it sits on (PAD, following slabs' slanted ends and panels' cut corners), is drawn
  smaller than `MinTextSize` (11 px; `MinTouchTextSize` 14 px on touch) on screen (SMALL),
  overlaps another text on the same box (OVERLAP) or is off screen (OFFSCREEN). One
  `[UiAudit]` line per problem, a SUMMARY line, optional red outlines.
- One padding rule: `Ui.pad(object, x, y)` (UIPadding; defaults `Config.Ui.TextPadX` 12 and
  `TextPadY` 6). A label that fills its box takes `Ui.pad`; a label placed by offsets keeps the
  same gap from the box edge. `Ui.shrinkText` now also cuts a text off with "..." when it still
  doesn't fit at its smallest size, and never shrinks below `Config.Ui.MinTextSize` (11, so the
  old 8 to 10 minimums are 11). `Ui.button` labels pad clear of the slanted ends and shrink.
  `Ui.setTextSize` keeps a shrinking label's maximum in step.
- Fixes by screen are in the table below (money pill, level bar, nav, Shop, Locker, Quests,
  Rewards, Leaders, popups, HUD, toast, spectate bar, results card, win screen).
- Test hooks, additive: `Ui.pick(row, name)` / `Ui.tabNames(row)` (click a `Ui.tabs` tab from
  code), `Profile.setOverride(sample)`, `LeadersTab.sample(payload)`, `Hud.preview(text)`,
  `RoundResults.preview(info)` / `.hide()`, `WinScreen.sample(info)` / `.close()`.

## Files
`src/client/DevPanel/UiAudit.luau` (new), `DevPanel/DebugTab.luau`, `Menu/Ui.luau`,
`Menu/init.luau`, `Menu/ShopTab.luau`, `Menu/ItemCard.luau`, `Menu/QuestsTab.luau`,
`Menu/LeadersTab.luau`, `Menu/RewardsTab.luau` (economy's file: spacing and layout only, no
logic; watch for a merge conflict), `Menu/LockerTab.luau`, `Menu/Popups.luau`, `Hud.luau`,
`Notify.luau`, `Spectate.luau`, `RoundResults.luau`, `WinScreen.luau`, `Profile.luau`,
`src/shared/Config.luau` (`Config.Ui` gains `TextPadX`, `TextPadY`, `MinTextSize`,
`MinTouchTextSize`, `MinPadding`, `MinPaddingY`), `AGENTS.md` (module-table rows only).

## How to run the auditor
1. Dev panel (` key) > Debug tab > "UI audit". Output window open.
2. "Scan the UI now" checks what is on screen right now (open a window yourself first if you
   want that one). "Open every window with worst-case content, then scan" opens the Shop, Locker,
   Quests, Rewards and Leaders (every tab and chip, first with a broke fake profile, then a rich
   one with 7-digit numbers, level 100 and the longest item names), then popups (earned, level-up,
   reward card, crate reel, Iridescent shout-out), toast, banner, spectate bar, results card and
   win screen with 20 x "W" names. About a minute; don't click meanwhile. Nothing is sent to the
   server (the fake profile is local: `Profile.setOverride`).
3. Each line looks like
   `[UiAudit] PAD [Shop rich Daily shop] Menu.Root.Window.Body.Shop.Daily.ScrollingFrame.Foo.Name "WWWW..." : room to the box edge: left 5 px (least 8 sideways, 4 above/below; box ...)`.
   The first word is the kind, the bracket says which window and fake profile, then the full path
   of the label, its text, and the numbers (real pixels at the current window size). The first
   line of a run prints the screen size, UI scale and a calibration (see below). The last line is
   `SUMMARY ... N problems (FIT a, CUT b, PAD c, SMALL d, OVERLAP e, OFFSCREEN f)`.
4. "Outline problems in red" (toggle) draws a red box with the kind on every problem of the next
   run until "Clear outlines". Outlines of a sweep are over what was open when each state was
   scanned, so they are mostly useful for "Scan the UI now" with the window you are looking at.
5. "Touch text rule (14 px)" is on by default on touch devices and flags all text under 14 px.
   Turn it off to use the 11 px rule everywhere.

### What it measures, and what it does not
- Real pixels at the current size. It calibrates first with throwaway labels (and prints the
  result in the first line): whether `AbsoluteSize` and `TextBounds` include UIScale (it assumes
  `AbsoluteSize` does and `TextBounds` does not, and checks), the line height of each font, and
  where `AbsolutePosition` puts the top bar's inset. If a number looks off by exactly the UI
  scale, send me the header line.
- "The box" behind a text is the nearest ancestor with a visible fill (Frame background, a
  `Ui.slab` / `Ui.panel`, a bordered frame, or a filled child that covers it, like a button's
  Fill), only if the middle of the text lies inside it (so floats and hanging badges are skipped).
  Sideways padding is stricter (8) than above and below (4): a line's measured height already
  includes space above and below the letters.
- Overlap is only checked between two texts on the same box. Two boxes overlapping each other is
  not reported unless a text spills out of its own box (PAD "sticks out").
- Texts clipped away by a scroll list are skipped; texts partly clipped by a scroll list edge
  are not reported (normal scrolling). Transient states (a popup mid-pop, the win screen's
  rewards card before it slides in) can report OFFSCREEN; the sweep waits for each to settle.
- A shrink-to-fit label's drawn size is estimated from its height; a multi-line shrinking label
  (the Rewards day tiles) is over-estimated, so SMALL under-reports there.
- Not covered: the Locker's 3D preview, the world titles over heads (BillboardGui), the lobby's
  boards and signs (text parts built by `tools/lobby_layout.py`, which checks its own text
  sizes), the train's departure boards, tag effect text in the world, and the dev panel.
- The sweep cannot open anything that needs real server data except by faking it: the
  Leaderboards payload is injected (`LeadersTab.sample`), the profile is faked, the results card
  and win screen are previews. The Locker opens only if the Locker is available to you now (not
  mid-round). Real "Need N more" prices come from today's real rotation, so the longest real
  names are only seen if they are in today's shop (the dev panel can move the clock a day).

## Findings: worst-case review and what was done
Sizes considered: 1280x720 (scale 1.0), 1366x768 and 1920x1080 (same layout, bigger), 812x375
and 375x812 (touch, scale 0.85: virtual 955x441 and 441x955). "Virtual" = layout pixels. All
numbers are estimates from the code (Titillium caps about 6.5 px per character at 11, 8.5 at 14;
Bangers about 0.45 of its size per character), not measurements.

| Where | Worst case | Problem | Fix |
| --- | --- | --- | --- |
| Menu money pill | 9,999,999 coins | text ran to the slanted end | text box 58 clear of the end; still shrinks to 11 |
| Menu level bar | "LV 100", "9,999,999 / 9,999,999 XP" | plate 78 wide, text about 60: 9 px each side | plate 92, text pads 12 and shrinks |
| Menu nav buttons | page names | label 56 clear, 4 px from the slanted end | 64 clear, shrinks |
| Window header (all pages) | title + info ("12 / 60 OWNED") | title (60%) and info (40% less 4) boxes overlapped by 18 px; info could shrink to 9 px | title 58%, info starts 8 clear of it, minimum 11 |
| Every `Ui.button` | long label ("Open all (10)", "Crates only: 0.05%", Robux price) | label sat flush with the slanted ends and spilled | label pads clear of the slant, shrinks to 11, then "..." |
| Badge counts | "99" | 18 high with 12 px text | 20 high, 8 side padding |
| Shop: header rows | "NEW ITEMS IN 23H 59M" | boxes touching (40/60%) | 4 px gaps, left shrinks too |
| Shop: Mystery crate (wide, body 680 to 788) | note, odds line, "YOU HAVE 99 · NEED 9,999,999 MORE" | the note wrapped onto the odds bar; the owned/need line (160 wide, one line) ran left over the odds | text column leaves 330 on the right; note 2 lines; the line under the button is 190 wide, 2 lines, cut with "..." ; crate 116 high |
| Shop: Mystery crate (narrow) | same | 3-line note and 44 px odds fit but 14 px side gaps | 106 reserved right, button full width, 184 + button high |
| Shop: offer cards | name 20 characters; "Need 12,340 more"; price 5 digits | text 8 px from card edge; name box 20 high touching the button (2 px); "Need ..." box 71 px wide in 2-column narrow cards wrapped to 3 lines | 12 px side gaps, name 22 high, card body 126, buy button 100 wide and the need text starts at 120 (2 lines max) |
| Shop: deal card | long name in Bangers 30; "was 12,500"; ribbon | ribbon 104 wide with unpadded text | ribbon 112, padded, shrinks; narrow deal card +12 high so "Need ..." clears the name |
| Shop: coin packs | "13,000", "BEST VALUE", "+30% BONUS" | tag strip 18 high with 11 px text; amount unpadded | strip 22, content moved down 4, amount and bonus padded |
| Shop: passes | "Double coins from every game" next to a 110 px button | text box ended 76 px short of the button but wrapped to 2 lines in 30 | text box 44 high, 184 reserved right, cut with "..." ; card 88 high |
| Locker plate | 65-character blurb, "NO. 12345" with a long rarity line | description box 36 high; serial 16 high | 42 and 18 high; serial shrinks |
| Locker tiles | "PERFECT ATTENDANCE" in a 100 px tile | name 3 px from the tile edge; "ON" tag 14 high | name box 8 px in and 17 high (cut with "..."), ON tag 30 x 20 |
| Locker (Victories) | the Victories note | it was a text in the tile grid: a 94 x 76 cell, 5 lines overflowed | moved into the count line ("... EPIC AND UP") |
| Quests rows | "12,345/50,000" count in 64 px; "WALL RUN 1,000 TIMES"; reward lines | count box overlapped the title column by 6 px and was too narrow; sub line touched the bar (2 px) | count box 96 (88 narrow) and shrinks, text column 256 from the right, row 68 high with the line, sub and bar separated |
| Quests: footnote | 66-character line with an icon, 441 px page | wider than the page | wrapped, 2 lines, padded |
| Rewards: streak header | "RESETS IF YOU MISS A DAY" in 40% of 413 | cut | both shrink, gaps |
| Rewards: day tiles (7 across) | "CLAIM 300 + CRATE" on day 7 | 52 px tiles on a narrow page (413/7), text 88 | 4 columns when narrow (2 rows), tiles 76 high, crate reward on a second line, text pads 12 and shrinks |
| Rewards: crate + odds | 441 px page | odds panel 181 wide: rows negative, note 4 lines | stacked when narrow (under 560); odds note 34 high from the top, rows no longer touch it (panels 184) |
| Rewards: "Get more" line | 62 characters | 89 px wide beside the buttons on narrow | under the buttons when narrow, 2 lines |
| Rewards: "Last opened" | 8 chips with long names | one row ran off the page | wraps (UIListLayout.Wraps), chip text 12 px in |
| Leaders: list rows | 20-letter names, 7-digit values | name box overlapped the value box by 10 px; names only truncated | name 244 clear, shrinks to 11 then "..."; value shrinks |
| Leaders: podium | 20-letter names, 7-digit values | the crown was clipped by the scroll list's top (its bottom was 4 px inside it), 3rd place's rank number and value texts overlapped, name unscaled | podium 196 high, crown above the face, rank number above a value at the block's foot, names shrink |
| Leaders: stat tiles | "100h 59m", "BEST WIN STREAK" | text 10 px from the edge | 12, label 16 high |
| Popups: reward card | long item names, long reason | title flush with the slanted header | title pad 18, lines 16 in, shrink min 11 |
| Popups: crate reel | "YOU GOT <20 char name> NO. 12345!" at 20 px in a 385 px window, 9 other items | result ran off the window; "ALSO" list wrapped past the window | result shrinks; "ALSO" shows 5 items and "+N MORE", 2 to 3 lines, window 26 higher |
| HUD banner | "<20 W> WINS!" in Bangers 60 | unscaled text ran off a narrow screen; band 84 high | text keeps to 70% of the band and shrinks (min 20); band 92 high |
| HUD status line | long status | fixed 560 wide, 20 high, wrapped onto the next object | up to 560, narrower on small screens, grows with its lines |
| HUD bar | "ROUND 12", "30 LEFT" | 46 px content with 38 px Bangers | bar 54 high, timer 36 |
| Toast (Notify) | "<name> fell and is out!" (two 20-letter names) | auto width, off a narrow screen | width capped at the screen's, cut with "..." |
| Spectate bar | "SPECTATING <20 W>  ·  Q / E TO SWITCH" in a 340 bar; 682 px wide row on a 441 px screen | label overflowed; row off screen | label shrinks and pads; the row wraps (bar on top, three buttons under) when it does not fit; buttons `Ui.hit` high |
| Results card | 20-letter names, "100 PLAYERS LEFT", 12 out | name box 60% beside a 112 tag; title unpadded; card 440 wide and up to 510 high on a 441 px phone | name 132 clear of the tag and shrinks; counts and titles shrink; card width and list rows follow the screen |
| Win screen headline | "<20 W> WINS!" Bangers 52 + 72 padding | about 700 px wide, off a 441 px screen | text size picked to fit the screen |
| Win screen plates | three 230 px plates | overlapped on screens under about 800 px | each plate scales to stay clear of its neighbour (min 0.6) |
| Win screen rewards card | "NEW PERFECT ATTENDANCE", "30TH OF 30" | fixed 360 wide, header texts unscaled | width follows the screen, header shrinks |

## Not fixed, or not sure
- **Touch text size.** With the touch rule on, almost every 11 to 13 px label is flagged (virtual
  sizes at touch scale 0.85 give 9 to 11 real pixels). Meeting 14 px means raising text sizes or
  `TouchMinScale` across the board: a design decision, left to the owner. Phones are still not a
  goal (see `notes/ui.md`).
- **Line height.** The tall Titillium line height (about 1.5 of the size, if Roblox uses the font's
  metrics) matters for every box height here; the auditor prints the measured value in its first
  line. If it is much more than 1.2, send it to me: several 14 to 20 px high boxes holding 11 to
  13 px text (a lot of the "above/below" gaps) will show PAD lines I expect to be borderline.
- **TextScaled + TextTruncate.** `Ui.shrinkText` now sets both. I expect truncation to work at
  the minimum size but have not seen it; if a long name shows no "..." and spills instead, the
  auditor will print FIT with "already at its smallest size".
- **Button labels with an icon** (`Ui.iconText`: the Locker's "how to get it" button, Equipped)
  don't shrink; their widths are fine for the real strings (20 characters at 13 px) but a longer
  one would overflow.
- **HUD, win screen, spectate bar and toast are not in the scaled root** (the menu is). They use
  real pixels, so on a 4K screen with a high UI scale they look small. They now fit narrow
  screens, but a UIScale for them is a bigger change (`Ui.scale` keeps one shared state).
- **Rewards day tiles** over-estimate their shrinking text (two lines); the real size is probably
  11 to 13.
- **The rewards card on the win screen** has no scrolling: 9 or more rows on a 375 px high screen
  would be cut off. Realistically 4 to 6 rows.
- `RewardsTab.luau` belongs to economy; my edits there are spacing and layout only.
- Lobby boards (text parts) and world titles: not checked here.

## What the owner should do
1. Studio window sizes to try (drag the window, or the device emulator): 1280x720, 1366x768,
   1920x1080, 1024x768, 812x375 (touch), 375x812 (touch).
2. At each: dev panel > Debug > "Open every window with worst-case content, then scan". Be in the
   lobby (not mid-round) so the Locker opens; have the Output window up. Don't touch the mouse
   for about a minute. Copy everything starting with `[UiAudit]` and send it to me.
3. Then look at the screens yourself with "Outline problems in red" on and "Scan the UI now" for
   the window you have open: Shop (Daily and Coin), Locker (all four tabs), Quests (both tabs,
   chips), Rewards, Leaders (both tabs). Also: a toast, the spectate bar (eliminate yourself), the
   results card and the win screen (dev panel > Game > "Show (3)").
4. Check specifically: the Shop crate box and "Need N more" at 1280x720 and 375x812; Rewards at
   375x812 (day tiles in two rows, crate over odds); the Leaders podium (crown visible); the
   header of every window (title and info not touching); the spectate bar at 375 wide.
5. Tell me anything the auditor misses (text that looks cramped but is not reported) and I will
   tune `MinPadding`, `MinPaddingY` and the box rules.
