# Victories: the new set

Plan for the new victory animations (the winner's celebration on the win screen, also previewed in
the Locker). Steps: polish the ideas (this file), then a basic moving mockup of each one to look at
and tweak, then build them in the game.

## Where they play (what each design has to fit)
- **Win screen** (`client/WinScreen`): the winner's copy stands on the 1st place block (9 wide, 8
  deep, 6 high), with 2nd and 3rd on blocks 4.5 and 3 high either side (2 studs apart), and a tall
  backdrop wall 14 behind. The camera pushes in for the first 2.4 s, then holds. The victory
  starts at 0.7 s and the screen fades at 8 s, so a victory has about **6.5 s**, and the end pose
  holds until the fade. The rewards card slides in at 3 s (bottom of the screen).
- **Locker** (`client/LockerStage`): your own copy plays it on a loop (every 5 s now) on the
  showcase stage, in the free space beside the menu. There's no podium there yet, so the podium
  victories need a stand-in block.
- **The body** is the classic 2012 block rig. Poses are keyframes per body part
  (`AnimationBuilder`); props (trophy, katana, throne, crown) are built from parts and welded to
  a hand or placed in the world. Everything runs on each screen only, from the same data, so
  everyone sees the same thing.
- **Pieces we already have** (from the tag effects): lightning bolts, the meteor, Shatter's holo
  shards and screen flash, bursts, confetti, the spotlight, the holo palette.

## What each rarity gets
- **Epic**: one signature move plus an effect in the item's gradient colours. It stays on the
  podium: no props bigger than the player, and nothing in the scene changes.
- **Legendary**: changes the scene (the podium, the sky, big props), with camera moments (shake,
  tilt) and a gold or electric theme.
- **Exclusive** (earned, green): Trophy Lift, Epic sized.
- **Iridescent**: the holo palette, takes over the whole screen, and has one moment nothing else
  has.

Times below are seconds from when the victory starts.

---

## Epic

### Flex (kept)
Unchanged: both arms up in a double bicep, with a gradient sparkle burst.

### Backflip
A clean, high backflip that lands in a superhero crouch.
- **0.0** Quick dip, arms swing back.
- **0.25** Springs up about 6 studs into a tucked backflip (one full turn), with a short gradient
  trail off the feet.
- **1.0** Lands in a three-point hero landing: one knee down, a fist planted on the block, the
  other arm out behind, head down. A dust ring and a gradient shockwave run along the block's top,
  the camera dips slightly, and small cracks glow on the block for a moment.
- **2.2** The head slowly comes up to look at the camera.
- **End pose:** the hero crouch, looking up.

### Confetti Storm (replaces Confetti Pop)
The whole scene gets buried in confetti.
- **0.0** Both arms up. Two confetti cannons pop from the hands (a burst up).
- **0.5** Confetti rains from above the camera for the rest of the victory, in the item's colours.
  Some pieces flutter across the screen in front of the camera, and a few stick for a second and
  slide off.
- **0.8 onward** Pieces that land stay where they fall, building a carpet on the ground, the
  blocks and the players' heads and shoulders (capped at about 150 pieces).
- **3.5** The winner brushes confetti off a shoulder, then throws both arms up again.
- **End pose:** arms up, standing in a pile of confetti.

### Breakdance
A breakdance power move that snaps into a freeze.
- **0.0** Drops to the floor: hands down, legs kick out.
- **0.4** Windmill: rolls over the shoulders and back with the legs in a wide V circling over, about
  four turns, getting faster. Gradient trails come off the feet and dust swirls.
- **2.6** Snaps into a freeze (balanced on one hand and the head, body tilted, legs bent in the air).
  A bass-hit ring pulses out and the camera gives a tiny shake.
- **End pose:** the freeze, with a small head nod on the beat.

### Katana
A clean draw, a spin and a sheathe.
- **0.0** A sheathed katana fades in at the left hip, and the right hand goes to the hilt.
- **0.3** Draws it in one fast motion: the blade glints and a gradient slash arc appears in front.
- **0.8** Spins it in the hand twice, swings it overhead, then makes one wide horizontal cut. That
  cut's arc hangs in the air.
- **2.6** Slowly brings the blade back to the sheath.
- **3.2** Snaps it home. On the click the hanging arc splits apart and scatters as petals in the
  item's colours, and a thin bright line flashes across the backdrop.
- **End pose:** standing tall, head slightly down, hand resting on the hilt.

---

## Exclusive

### Trophy Lift (the level 20 reward)
A gold cup lifted high like a cup final. Earned, not in crates or the shop.
- **0.0** Reaches behind the back.
- **0.4** Brings out a gold trophy (a two-handled cup on a stem and base, with ribbons in the
  item's colours), holds it in front and admires it.
- **1.2** Lifts it high overhead with both arms straight. A glint sweeps across the cup, then a
  burst of gold sparkles and soft gold rays behind it.
- **2.2 to the end** Pumps it up twice, then holds it high.
- **End pose:** trophy held overhead.

---

## Legendary

### Podium Rise
The 1st place block erupts out of the ground.
- **0.0** The ground rumbles: camera shake, and dust puffs off the block's edges.
- **0.5** Glowing gold cracks spread round the base of the 1st block.
- **0.8** The block bursts up about 8 studs. Rocks and dust spray out, rubble falls off its sides,
  and the winner crouches for balance as it rises. The camera tilts up to keep them in frame.
- **2.0** A gold spotlight slams on from above: a visible beam with gold flecks drifting down
  through it. The winner stands tall with one fist in the air.
- **2nd and 3rd** look up at them.
- **End pose:** arms spread wide in the beam, on the risen block.

### Thunderstorm
- **0.0** The sky darkens to a stormy blue, the light dims and clouds churn over the backdrop.
- **0.6, 1.0** Two warning bolts hit the ground near the podium.
- **1.4** The big bolt hits the winner: a white flash on the screen and a hard camera shake. They're
  lifted about 2 studs off the block, arms out and back arched.
- **1.4 to the end** They hover with a slow bob. Electric arcs crackle between their limbs and the
  block, sparks fall, and the block's edges glow blue.
- **3.0** The sky comes back, a little darker than normal.
- **End pose:** hovering, arcs still crackling.

### Throne
- **0.0** A shadow grows on the block behind the winner.
- **0.6** A big gold throne with velvet in the item's colours crashes down behind them. Dust, a camera
  shake and bits of debris. It's wider than the block and overhangs the back.
- **1.0** The winner glances back over a shoulder.
- **1.3** Falls straight back into it (a trust fall) and lands lounging: legs crossed, an elbow on
  the armrest with the chin on that fist, the other arm draped over the side.
- **2.0** A gold crown sparkles into being above the head, spins slowly and settles floating just
  over it, glowing.
- **End pose:** lounging, crown floating.

### Meteor Touchdown
- **0.0** Crouches to charge, with embers rising around them.
- **0.4** Launches straight up out of the frame on a fire trail. The camera tilts up a little after
  them.
- **1.3** Comes back down as a meteor, wrapped in fire, diving fist first.
- **1.8** Slams into the 1st block: a big flash, a fiery shockwave ring along the ground and a heavy
  camera shake. The block's top cracks and glows, and chunks break off its edges (it erodes and
  stays broken). Smoke rises, and 2nd and 3rd stagger back.
- **2.4** Rises from a three-point landing in the crater.
- **End pose:** standing in the smoking, glowing crater, embers drifting up.

---

## Iridescent

### Supernova (replaces Hologram)
- **0.0** Holo crystal shards (glassy wedges that shift colour) start orbiting the winner, who rises
  slowly with arms out (about 8 studs by 2.0). The shards swirl faster and tighter into a sphere.
- **2.2** The peak: everything freezes for half a beat, and the winner curls in.
- **2.6** Explodes: a chromatic shockwave ring rushes out, the screen flashes with a colour split,
  and the screen cracks like glass. Holo cracks race out from the winner, the screen breaks into
  iridescent glass pieces that drift apart a little, then slowly slide back together and fade away.
- **3.4 to the end** The winner floats at the peak with prism rays turning slowly behind them and
  colour trails streaming off. The remaining shards orbit gently.
- **End pose:** floating, arms out, head back, rays turning.
- **Limit:** Roblox can't capture the screen as an image, so the "shattered screen" is drawn glass
  (holo crack lines and tinted shard shapes over the screen), not the real picture breaking apart.
  It still reads as the screen breaking.

### Rift
- **0.0** The winner raises a hand, and holo energy gathers in it like a blade.
- **0.5** Slashes the air: a jagged tear opens beside and behind them, edged in holo colours, with a
  starfield swirling inside.
- **1.2** The rift widens. A celestial dragon of energy (a glowing serpent of segments with a head
  and a holo trail) pours out.
- **1.5** The dragon spirals round the winner twice, top to bottom.
- **2.5** The world turns over. The sky and backdrop become a neon nebula, the ground under the
  podium becomes a glowing space floor (stars and swirling colour), and the blocks glow at the
  edges.
- **3.8** The dragon coils up overhead and bursts into stars, and the rift seals with a flash.
- **End pose:** standing calm in the nebula, energy wisps around the hands. The nebula stays until
  the fade.

---

## Changes after the mockup (2026-10-30, now built)
- **Backflip** is a real backflip: the body turns backwards a full turn with the knees tucked.
- **Breakdance** is a real windmill (rolling over the shoulders and back, legs in a V) and ends
  in a one-hand freeze with one leg sticking straight out.
- **Katana**: the draw and the sheathe are animated (the blade slides out of and back into the
  sheath), with the spin in between. When it clicks home, the 2nd and 3rd blocks are cut along a
  slant and their top halves slide down the cut, with the players on them.
- **Trophy Lift** is Epic (crates and the shop), and still the level 20 reward.
- **Meteor Touchdown**'s shockwave reaches round the podium: the floor cracks out to about 26
  studs, a scorch spreads, and every block chips, cracks and jolts as the wave reaches it.
- **Rift** has no rainbow and no dragon. The tear is pink. The winner is pulled into it,
  tumbling, and the stage is gone: they float in deep space (dark blue-black, stars). A pink
  shooting star streaks past, then a supernova erupts behind them: a pink flash, wisps of
  plasma flaring out, and drifting pink points of light all round, soft and out of focus.

## Polish after the first build (2026-10-30, 0.55.1)
- Characters glowed on the win screen (the lobby's night bloom was still fading out); the win
  screen now has its own lighting, switched at once behind a short black hold.
- No name plate under the winner (it covered the rewards card).
- Breakdance never sinks into or floats over the block; Katana's sword follows one smooth path
  with the arms reaching for it, and the competition's blocks are sliced and fall, the players
  flopping to the floor; Trophy Lift comes out of a pocket and goes clear over the head, no rays;
  Podium Rise keeps its number, follows the winner with the camera, darkens the stage under the
  spotlight and wrecks the floor round the block; Thunderstorm has heavy rain; Meteor Touchdown
  deforms every block and wrecks the floor; Rift's star arcs and its supernova is far bigger.

## Katana becomes Fruit Ninja (0.55.5)
A longer, sharper blade. After the draw and the spin: an apple (diagonal slash), a banana (a
sweep) and a watermelon (a two-handed chop) are tossed up and sliced mid-air, the halves showing
their insides and juice flying. Last a bomb with a lit fuse is cut by the big hanging cut and
blows up in front of the podium: 2nd and 3rd's blocks go over onto their sides and the players
are thrown to the floor like ragdolls. Then the clean sheathe and the petals.

## Chrysalis (replaces Supernova): planned 2026-10-30, not built yet

Supernova is being replaced by **Chrysalis**, an Iridescent victory with its own style: organic
and graceful (silk, a cocoon, morpho butterfly wings, a stage overgrown with plants), not
explosive, and nothing like Rift (deep space, pink particles, the green planet). The item keeps
its id `victory_supernova` (owners keep it) but is renamed "Chrysalis". About 10 s long.

**Palette.** Wings and butterflies: morpho blue at the base shifting to violet and teal at the
tips (deep blue 20,70,220 to electric blue 40,140,255 to violet 140,80,255 to teal 40,220,210),
dark veins, slowly sliding colours. Silk and cocoon: pearly white with a faint holo sheen (pale
pinks, mint, lilac sliding across it). The overgrowth: rich greens (moss 60,110,40; grass
90,160,50; leaves 50,130,45 and 120,190,60) and flowers (white, soft pink, lilac, yellow
centres). Light: warm, soft, the stage slightly dimmed so the glow stands out.

### The beats (seconds from when the victory starts)

**0.0, Overgrowth (the moment it loads).** All the stage's neon goes dark at once (the
backdrop's neon slashes, the yellow strip; the lamps dim to soft warm light). Then nature grows
over the whole stage as an animation, spreading out from the 1st place block:
- moss creeping across the floor and up the sides of all three blocks (patches growing from
  nothing and spreading),
- grass tufts sprouting (blades growing up), clumps along the block bases and the floor,
- vines climbing the backdrop wall and the block fronts, leaves unfurling along them,
- small plants and ferns unrolling, flowers blooming (buds opening into petals: white, pink,
  lilac, yellow centres), a few on the block tops round the players' feet,
- a few leaves drifting down, pollen and soft light motes floating in the air.
The growth keeps going lightly for the whole victory (the occasional new flower opening). 2nd
and 3rd look round at it.

**0.6, Silk rises.** Shimmering silk threads spiral up from the 1st block around the winner,
catching the light with small glints as they climb. 2nd and 3rd look over at the winner.

**1.2, Wrapping.** The threads tighten and wind round the winner from the feet up while they
cross their arms over their chest. Layer by layer a pearly cocoon forms round them, its surface
sliding with a faint holo shimmer, until they're fully hidden.

**2.2, The heartbeat.** The cocoon lifts slightly off the block and hangs there. It pulses with
light three times like a heartbeat, each pulse brighter (blue-violet light from inside). Light
leaks through hairline cracks. The camera slowly pushes in.

**3.4, The hush.** The cracks spread across the whole shell. Everything goes still for half a
beat, the light inside at its brightest.

**3.8, The burst.** The shell breaks into pearly flakes, and each flake turns into a butterfly
as it flies: hundreds of glowing butterflies (the wings' morpho blue, violet and teal) burst
outward and fill the screen. 2nd and 3rd shield their eyes.

**3.9, The wings unfold (the signature moment).** Huge wings unfurl from the winner's back,
about 14 studs across, filling half the screen, opening slowly over about a second: deep blue at
the base shifting toward violet and teal at the tips, dark veins, an eyespot on each lower wing,
a glowing edge, a light dust drifting off them. The colours keep sliding as the wings move.

**4.8, The first flap.** One big, slow wing beat sends a soft ring of light rippling out across
the overgrown stage; flowers and grass sway in the gust. The butterflies sweep into a spiral
round the winner.

**5.1 to the end, Rising, and the butterflies leave.** The winner floats upward about 5 studs,
wings beating slowly about once a second, arms open and head up. The camera follows them to keep
them centred. The butterflies circle in a slow vortex round them. One butterfly lands on the
winner (a shoulder or a raised hand) and rests there, opening and closing its wings. The rest fly
round the screen and then, wave after wave, come straight at the camera and fly out of view past
it until none are left. The butterfly on the winner waits 0.5 s after the last of the others has
gone, then flies off too.

**End pose:** hovering mid-air, wings fully spread, still beating slowly, the overgrown stage
below, a few petals and motes drifting.

### Rules for it
- Keep the winner the focus: nothing covers their face or body (butterflies, flakes and dust
  avoid the winner's place on screen, as Rift's particles do), and they stay lit.
- 2nd and 3rd react: look round at the overgrowth, look at the winner, shield their eyes at the
  burst (with the arm on the winner's side).
- No emoji, no white glare, no plus-sign sparkle texture (soft round dots).
- In the Locker preview there's no podium and no other players: the overgrowth grows on the floor
  round the character instead.

### Step 1: the mockup artifact (first, before any game code)
A detailed animated mockup page of Chrysalis to review before it's built, like the earlier
"Victory Mockups" page (https://claude.ai/artifact/4E4KHwTzbB3gLbsjGEKhb4) but for this one
victory and far more detailed:
- The win screen front view: the stage (backdrop wall with neon slashes, floor, the three podium
  blocks 1st, 2nd, 3rd with their numbers, block-rig characters on them; the winner classic
  yellow head and arms, blue torso, green legs).
- Every beat above, timed as written and drawn in detail: the neon going dark, the overgrowth
  growing (moss spreading, grass blades rising, vines climbing with leaves unfurling, flowers
  blooming petal by petal), the silk threads spiralling, the cocoon building in layers with its
  sheen, the heartbeat pulses and cracks, the flakes turning into butterflies, the wings
  unfolding (veins, eyespots, glowing edges, sliding morpho colours), the light ring on the first
  flap, the rise, the vortex, the butterfly landing, the waves of butterflies flying at the
  camera and out of view, the last butterfly leaving 0.5 s later.
- Butterflies must read as butterflies: a body and two pairs of wings that flap.
- Controls: play and pause, replay, half speed, loop, a timeline scrubber with beat markers, and
  the beat list under it (click a beat to jump to it).
- One self-contained HTML file (canvas; three.js from cdnjs is fine if 3D helps), the page in
  the game's Street sprint look (dark, Bangers and Titillium Web, hazard yellow).
- Publish it with the Artifact tool, title "Chrysalis Mockup". No game code changes in this
  step: the owner reviews the mockup first.

### Step 2 (after the owner signs off the mockup): build it
Replace `Iridescent.Supernova` in `src/client/Victories/Iridescent.luau` with `Chrysalis`
(`look.Victory` "Chrysalis"; rename the item to "Chrysalis" in `shared/Catalog.luau`, keeping the
id `victory_supernova`; update the Locker's `VictoryFrames`), built from the Kit (props and prop
scale, `Kit.reach`, `Kit.lookAt`, `Kit.darken`, `Kit.react`, `Kit.hide`; wing panels painted
with SurfaceGuis like Rift's planet). Then the usual: AGENTS.md changelog, version bump, checks,
commit, push.

## Decisions (2026-10-30)
- **The new set only:** Flex stays. Confetti Pop, Backflip, Fireworks, Hologram and Graduation are
  removed. Owners get the closest new one: Confetti Pop to Confetti Storm, Backflip to the new
  Backflip, Fireworks to Podium Rise, Hologram to Supernova, Graduation to Trophy Lift.
- **Trophy Lift** is the level 20 reward in place of Graduation (Epic since the mockup).
- **Length:** Epic and Exclusive keep the 8 s win screen. Legendary and Iridescent stretch it to
  about 10 s (each victory says how long it needs, and the server sets the win screen's length from
  the winner's victory). The Locker's loop follows each victory's length too.
- **Camera:** victories can shake, dip and tilt the camera, always coming back to the podium shot.
  The same moves play in the Locker preview.
- **2nd and 3rd react:** they look up at Podium Rise, stagger back from Meteor Touchdown and the
  Throne's crash, shield their eyes from the lightning, and get covered in Confetti Storm.

## Build list (built in 0.54.0)
1. Victory length and camera hooks: each victory's length (win screen and Locker), camera shake,
   dip and tilt, the runner-up reactions, and a stand-in block in the Locker.
2. Pose tools: keyframes that also move the whole body (jumps, flips, hovering), and props welded
   to the hands.
3. The Epic and Exclusive set: Backflip, Confetti Storm, Breakdance, Katana, Trophy Lift.
4. The Legendary set: Podium Rise, Thunderstorm, Throne, Meteor Touchdown.
5. The Iridescent set: Supernova, Rift.
6. Catalog: remove the old victories and swap owners to the new ones; level 20 gives Trophy Lift.
