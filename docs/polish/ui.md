# UI: Locker preview, small screens, menus

Owner: UI agent. Touches `client/Menu/*` (except `RewardsTab`, economy adds the codes box there),
`client/LockerStage`, `client/Menu/Ui`, `client/Hud`'s styling (flow owns its logic).

## What is wrong now
- **Locker preview hides behind the menu on small screens.** The Locker window is docked left at
  a fixed width (`DOCKED_WIDTH = 360` in `Menu/init.luau`, height `1 - 40`), but `LockerStage`
  points its scripted camera so the character is in the middle of the screen (fixed FOV, the
  `lookAt` offsets in its step function). On a narrow screen the window covers the character.
  The info plate (310 wide, top right) and the scene chip (300 wide, bottom right) are fixed
  pixel sizes too.
- **No touch swing.** `client/TagSwing` listens for `MouseButton1` and `ButtonR2` only, so
  phones and tablets cannot swing. (Slide, sprint and the dev tools also assume keyboard; not
  audited.)
- **Spectator controls are keys only** (Q/E/arrows). Flow adds buttons; UI makes them match the
  style.
- The other windows (Shop, Quests, Rewards, Leaders) use `fromScale(0.92, 0.78)` capped at
  820x560; small phones and ultra wide screens were never checked.

## Tasks, in order
1. **Locker camera fits the free space.** In `LockerStage`, compute the free rectangle of the
   screen (left edge = the window's right edge, right edge = the info plate) and shift the camera
   sideways so the character is centred in it. Shift = (window width share of the viewport) as a
   world offset at the character's distance, recomputed on `ViewportSize` changes. Clamp so the
   character is always fully visible; if the free width is under about 40% of the screen, stack
   the plate under the preview instead. Put the sizes in `Config.Locker`.
2. **Responsive helper.** Add `Ui.scale(gui)` (a `UIScale` driven by `ViewportSize` against a
   reference of 1280x720, clamped) and use it for the menu, HUD and popups so text sizes and
   buttons stay usable on phones. Minimum touch target 44 px.
3. **Small-screen audit.** Go through every window and popup at 1280x720, 1366x768, 1920x1080, a
   phone in landscape (812x375) and portrait (375x812), and a tablet (1024x768). Fix overflow,
   clipped text and unreachable buttons. Record fixes in the notes file.
4. **Touch swing.** Add a swing button on touch devices (and a touch slide/sprint if the owner
   wants phone support at all: ask first, it is a large piece of work).
5. **Spectate bar** with previous/next buttons, in the `Ui` style (coordinate with flow).
6. **Shop polish pass.** Check that prices, discounts, the countdown, the crate odds and owned
   states read clearly; empty states; long names. (Redeem codes UI is economy's.)

## Decisions for the owner
- Is phone/tablet play a goal? It decides how much of tasks 2 to 4 is worth doing now.
- Preferred placement of the Locker info plate on small screens.

## What the owner tests
Open the Locker at several window sizes (drag the Studio window narrow, or use the device
emulator): the character should always be fully visible beside the window. Open every other
window at a small size.

## Done when
No window hides its content at 1280x720, the Locker preview is centred in the free space at any
size, and the audit notes list nothing open.
