# Economy: rewards, pricing, XP and coin consistency, redeem codes

Owner: economy agent. Touches `server/Progression`, `PlayerData`, `Shop`, `Quests`,
`Achievements`, `DailyStreak`, `Config.Progression/Shop/Streak/Quests`, `shared/Catalog` prices,
`client/Menu/RewardsTab` (codes box). Payments are parked (`parked.md`).

## What the config pays now
- Game played 10 coins and 25 XP; surviving a round 20 XP and no coins; a tag 1 coin and 5 XP
  (at most 10 tags a round); a win 20 to 100 coins and 30 to 150 XP by players started (full at
  30), first win of the day 2x coins, streak bonus up to +100 coins scaled; a minute in a live game
  1 coin and 2 XP; top 5 bonus 15 coins in games that started with 20+.
- Levels: XP for the next level = 100 + 50 x (level - 1); coins on level up 25 + 5 x level; a
  free crate every 5 levels.
- Prices: Common 150, Rare 400, Epic 900, Legendary 2000; crate 300; the daily deal 30% off.
- Rough pace: a non-winner earns about 15 to 25 coins a game, so a Common is 6 to 10 games and a
  Legendary about 100.

## Problems
- Rewards are spread across many events with unrelated scales (a tag gives 1 coin but 5 XP, a
  survived round gives XP only), so it is hard to say what a "good" game pays.
- Nobody has checked that the amounts shown in popups, quests, rewards and the win text equal what
  the server pays.
- No pace targets exist (hours to a first Epic, crates per week).
- Redeem codes do not exist.

## Tasks, in order
1. **Simulator.** A script (Lune if `Config` can load, otherwise a Python table checked against
   `Config` by a small test) that prints, for 2, 4, 8, 12 and 30 player games and for a loser, a
   mid-table finisher and a winner: coins and XP per game, games to the next level, games to buy
   each rarity, crates per hour. Put it in `tools/economy_sim` and say how to run it.
2. **Targets with the owner** (clickable questions): hours to a first Rare, Epic, Legendary; how
   long a session is; how fast levels should come; how generous crates and the daily streak are.
3. **Rebalance** `Config` to the targets: one clear reward table, XP and coins in proportion
   across events, prices per rarity, crate price, level curve. Keep the win scaling by players.
4. **Consistency audit.** Every number the UI shows comes from the same `Config` entry or a single
   `Progression.preview` helper; fix any that differ (popups, QuestsTab, RewardsTab, ShopTab,
   the win screen).
5. **Per-game totals.** `Progression` tracks coins, XP and items earned during the current game
   per player and exposes them for the win screen (flow reads them; agree the shape first).
6. **Redeem codes.**
   - The code list lives in a **server-only** module (`server/Codes.luau`), never in `Config`
     (everything in `ReplicatedStorage` is readable by clients).
   - Each code: reward bundle (`Progression.grant`), optional expiry, optional global use limit,
     once per player (kept in the profile as `Redeemed`), case-insensitive.
   - `RedeemCode` remote: server validates the string, rate-limits (a short cooldown and a
     failure cap), grants, and answers with a `Notify`. A box in `RewardsTab` (UI style) with a
     result line.
   - A dev panel command to add a test code in Studio.
7. **Dead code.** Remove the reward wheel server module and `Config.Lobby.WheelPrizes` or keep
   them behind a note (owner decides; the Night Market has no wheel).

## Decisions for the owner
- The pace targets (task 2) and whether first-time players should get a head start.
- Which codes to launch with and what they give.
- Wheel: delete or keep for later.

## What the owner tests
Play a few full games in Studio with 2+ clients and watch coins and XP match the popups and the
numbers in the menu; redeem a code twice and a wrong code; check level-up and crate timing against
the targets.

## Done when
The simulator matches the agreed targets, no displayed amount disagrees with the server, and codes
work end to end.
