# UI agent notes (branch `polish/ui`)

Nothing here was run in Studio: only stylua, selene, check-syntax, mapcheck and `rojo build`
were run. Everything under "Unverified" below needs the owner's eyes.

## Changelog lines (for the overseer to merge into AGENTS.md)
- UI scales to the screen: everything in the menu and its popups is built in a scaled root frame
  (`Ui.scale`, a UIScale from the shortest screen side against 1280x720, clamped 0.75 to 1.5;
  `Config.Ui`). Layouts are in "virtual pixels"; pages get their body size (`Ui.bodySize`) and
  switch to narrow layouts (Shop, Quests, Leaders) on a narrow screen. `Ui.viewport`,
  `Ui.factor`, `Ui.onViewport`, `Ui.hit` (touch minimum 44 real pixels, touch screens only),
  `Ui.shrinkText` (a one-line label shrinks instead of spilling out) are new. Window titles,
  info texts, item names, coin totals and popup lines shrink to fit.
- The Locker preview fits any screen: new `Menu/LockerLayout` works out the window, info plate,
  scene chip and the free space beside them (three arrangements: side by side, a column when the
  gap is under 40% of the screen, a bottom sheet on a very narrow screen). `LockerStage` frames
  its camera every frame so the character (the scene's box in `Config.Locker.Frames`) is centred
  in that free space and fully inside it, backing the camera off if needed.
- Menu pages scroll where they were cut off on short windows (Leaders podium and list, My stats),
  with empty states (no shop offers, no quests, no achievements in a category, no scores).
- Shop: unaffordable prices say how many coins are missing ("Need 340 more", on offer cards and
  the crate), the crate's price was unreadable (dark on dark) when you couldn't pay and is not
  any more, the deal card says "was 1,200" with the old price struck out, the countdown turns
  pink in the last hour, long names shrink, the coin packs and passes reflow on a narrow page.
- Popups fit narrow screens (reward card, level-up and unbox stripes, crate reel).

## Files
`src/client/Menu/Ui.luau`, `init.luau`, `LockerLayout.luau` (new), `LockerTab.luau`,
`ShopTab.luau`, `ItemCard.luau`, `QuestsTab.luau`, `LeadersTab.luau`, `Popups.luau`,
`src/client/LockerStage.luau`, `src/shared/Config.luau` (`Config.Ui`, `Config.Locker`),
`AGENTS.md` (module table rows only).

## How it works (so you can check it against what you see)
- **Scale.** `Ui.scale(gui)` makes a `Root` frame under the ScreenGui with a UIScale `s` and
  `Size = fromScale(1/s, 1/s)`, so it fills the screen and its children are laid out in virtual
  pixels. `s = clamp(min(w/1280, h/720), 0.75, 1.5)` (0.85 as the lowest on touch devices, so a 44
  real-pixel button is at most 52 virtual pixels). 1280x720 gives 1.0, so it looks as before;
  1366x768 and 1920x1080 give the same layout, just bigger. `w, h` are the ScreenGui's
  `AbsoluteSize` (under the top bar).
- **Window.** Normal pages: 92% x 78% of the virtual screen, at most 820x560, as before. Body
  width = window - 32, height = window - 78, handed to the pages as `BodyW`/`BodyH` attributes.
  Under 680 wide (Shop) / 560 wide (Quests, Leaders) the narrow layouts apply.
- **Locker layout** (virtual pixels, W x H, window 360 wide at x=14, plate 310x168, chip
  300x28, edges 16, gap 16):
  - *side*: gap between the window (right edge 374) and the plate (left edge W-326) minus the
    two gaps, is at least 40% of W. W=1280: 548 of 1280 = 43%, so 1280x720, 1366x768, 1920x1080
    and 1024x768 (virtual 1280x960) are all *side*.
  - *column*: otherwise, if the column right of the window is at least 300 wide: the plate
    moves to the bottom right, the chip to the top right; the free space is the column between.
    A 1000x600 Studio window (virtual 1200x720) lands here, and the phone landscape 812x375
    (virtual 1083x500).
  - *sheet*: under 300 of column (virtual width under about 690, i.e. a phone upright): the window
    is a 50%-high sheet across the bottom, the chip and plate stack across the top, the
    character is between.
- **Locker camera.** For each scene `frame()` keeps the old camera direction, then (1) backs the
  camera off until the scene's box (`Config.Locker.Frames`, studs wide x high) fits the free
  rectangle: depth >= max(boxW/freeW, boxH/freeH) x viewportH / (2 tan(fov/2)); (2) slides it
  along its right and up vectors until the box's centre sits at the centre of the free
  rectangle. Free rectangle = layout free rect x scale factor + top-bar inset, in the camera's
  viewport pixels.

## Audit: what was found and fixed
Sizes are real screens; "virtual" in brackets. Fixes marked (all) apply everywhere.

| Where | Problem | Fix |
| --- | --- | --- |
| Locker, any narrow screen | Character hidden behind the 360 window; plate and chip fixed size, plate over the character | LockerLayout + LockerStage framing (above) |
| Locker header | "12 / 60 OWNED" cut off in the 360 docked window (info text was 40% of the header, no shrink) | (all) window title and info shrink to fit (`Ui.window`) |
| Locker tabs | Four tabs, 14 px side padding, could pass the 328 px body | padding 10 for these tabs |
| Locker tiles | Always 3 columns, wide cells in the bottom sheet | columns follow the window width |
| Locker plate | Long item name cut by truncation; description could run over the Equip button | name shrinks (18 to 34), description clipped to its two lines |
| Shop, narrow (375x812 portrait, virtual 441x955) | Deal card 230 wide beside four 90 px cards; crate text squeezed to 170 px with odds overflowing the panel; coin packs 5 across (about 80 px each) | deal above offers, crate button under its text, packs 2 across, passes stacked |
| Shop, any | Crate price dark-on-dark when you can't pay; no hint what's missing | readable dim price + "Need N more" |
| Shop, any | A shop with no offers showed an empty box | "Nothing in the shop today" |
| Quests, narrow | Title/bar left with about 130 px, reward text three lines in a one-line box | reward or Claim moves under the bar, rewards joined with a dot |
| Quests | Category chips (6) wider than a narrow body | padding 9 |
| Leaders, short windows (812x375: body about 270 high) | Podium 156 + list needed 220+; list rows overlapped "your rank"; stats page 320 px tall cut off | podium+list scroll between chips and your rank; stats scroll |
| Leaders, narrow | Podium columns 3 x 170 = 510 wider than the page; board chips and period chips overlapped | columns shrink to 31% of the page; period chips on a second row |
| Leaders, narrow | Stat tiles 4 across (about 100 px) | 2 across |
| Popups | Reward card fixed 380; stripes' text 52 px unshrinkable (unbox line, about 35 characters, ran off any screen narrower than about 800); crate reel window fixed 600 with a 568 px view | width follows the screen; text shrinks; reel width computed |
| Money pill | 7-digit coin totals ran out of the pill | shrinks |
| Touch (all) | Buttons 28 to 38 px | `Ui.hit`: tabs, buttons, close, nav buttons, Equip, Claim, shop buy buttons are at least 44 real px on touch screens (rows and cards grow to fit) |

Not changed (not mine): `Menu/RewardsTab.luau` (economy owns it). It now runs inside the scaled
root and gets `BodyW`/`BodyH`, but its own layout has not been checked on a narrow page: its
fixed-width pieces will need the same treatment (read `Ui.bodySize(page)`). The HUD, spectate bar,
win screen and notifications are separate ScreenGuis and are not scaled; they can call
`Ui.scale(theirGui)` and build in the returned root (it needs `Ui.scale` to run before they
build). I did not touch them.

## Task 4 (touch swing): not implemented, findings
Swing: `client/TagSwing.start` listens to `InputBegan` for `MouseButton1` or `ButtonR2` only. A
touch tap on the world arrives as `UserInputType.Touch` (not MouseButton1), and a tap on a
button is "processed". What it would take: an on-screen swing button (a `Ui.button`-style
`ImageButton`-like control from `Ui`, bottom right, shown when `UserInputService.TouchEnabled`
and a round is on or you're in the lobby), calling the same code as the click: factor the body of
the `InputBegan` handler into `local function trySwing()` and call it from both. About 40 lines,
not hard. What else assumes a keyboard (a phone is unplayable until these have touch controls):
- **Sprint**: hold Left Shift (`Config.Sprint.Key`, client/Sprint). Needs a hold/toggle button.
- **Slide / crouch**: C (`Config.Slide.Key`, client/Slide); also reads `JumpRequest` (so touch
  jump works for slide-jumps). Needs a button.
- **Jump**: Roblox's default touch jump button fires `JumpRequest`, so CoyoteJump and slide-jumps
  work; but `client/WallRun` reads `Enum.KeyCode.Space`/`ButtonA` directly for the wall jump (line
  about 280), so a touch wall jump needs `JumpRequest` too.
- **Spectate**: Q/E/arrows only (flow is adding buttons).
- **Camera**: `ViewMode` toggles with V (testing); first person on touch uses Roblox's camera.
- **Menu**: closes with Escape or the X (X works on touch). The lobby shop prompts are
  ProximityPrompts (E): Roblox shows a tap button for them on touch.
- **Dev panel**: backquote key (dev only; fine).
Also the menu itself is dense and meant for a mouse; on a phone the text is about 8 to 11
real pixels at the minimum scale. Decide whether phones are a goal
before spending more on it (the cheapest big win would be raising `Config.Ui.TouchMinScale`
and trimming what each window shows).

## Unverified (could not run the game)
1. A UIScale on a root Frame sized 1/s: standard behaviour, but I could not see the result.
   If anything is off by a constant factor, check `Ui.scale` first.
2. The top-bar inset: the camera framing assumes `ScreenGui.AbsoluteSize` excludes it and
   `GuiService:GetGuiInset()` is how much it takes (`Ui.inset`, `LockerLayout.freeReal`). If the
   character sits a little too high or low in the free space, that is the place.
3. `TextScaled` plus `TextTruncate` together (item names, popup lines, header text): shrinking
   works; I expect truncation only to matter at the minimum size.
4. Touch: `TouchEnabled` is also true on touch laptops, so those get the bigger minimum too.
5. The narrow layouts have never been seen. The numbers are worked out, not looked at.
6. Pages re-run their refresh when the window size changes while open (rotating a phone or
   dragging the Studio window); the Leaders page asks the server for boards only when opened.
7. The Hologram victory scene's box (18 x 20 studs at the statue) is a guess.
8. `Ui.hit` is read when a page is built, so a touch device that rotates keeps the old
   minimum (the button constraints do update; the row/card heights built from it do not).

## What the owner should test
Open each window at each size (Studio: drag the window, or the device emulator), with a few
coins and without enough for the crate:
- 1280x720 (should look as before), 1366x768, 1920x1080 (bigger, same layout), 1024x768.
- 812x375 phone landscape and 375x812 portrait (emulator; touch on).
- Locker, every tab: the character fully visible beside the window at all sizes, in the
  running, tagging, title and victory scenes (the Hologram victory especially), and the plate
  and chip not covering it. Drag the Studio window narrower while it's open: the layout should
  switch (side, then column, then sheet) without closing.
- Shop: Daily and Coin shop; deal card, owned, can't afford ("Need N more"), countdown colour
  in the last hour (the dev panel can move the clock), the crate and its odds.
- Quests: Daily and Achievements, every chip. Leaders: all boards, both periods, My stats.
- Popups: a quest Claim (card), a level-up, the crate reel (open from Rewards), an Iridescent
  unbox shout-out (dev panel), at a narrow size.
