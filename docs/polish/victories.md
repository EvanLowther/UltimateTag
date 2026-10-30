# Victories: the new set

Plan for the new victory animations (the winner's celebration on the win screen, also previewed in
the Locker). Steps: polish the ideas (this file), then a moving preview of each one to look at
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

### Hero Landing (the new backflip)
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

### Windmill
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

### Thunderstruck (Lightning Strike)
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

## Decisions (2026-10-30)
- **The new set only:** Flex stays. Confetti Pop, Backflip, Fireworks, Hologram and Graduation are
  removed. Owners get the closest new one: Confetti Pop to Confetti Storm, Backflip to Hero
  Landing, Fireworks to Podium Rise, Hologram to Supernova, Graduation to Trophy Lift.
- **Trophy Lift** is the level 20 reward (Exclusive) in place of Graduation.
- **Length:** Epic and Exclusive keep the 8 s win screen. Legendary and Iridescent stretch it to
  about 10 s (each victory says how long it needs, and the server sets the win screen's length from
  the winner's victory). The Locker's loop follows each victory's length too.
- **Camera:** victories can shake, dip and tilt the camera, always coming back to the podium shot.
  The same moves play in the Locker preview.
- **2nd and 3rd react:** they look up at Podium Rise, stagger back from Meteor Touchdown and the
  Throne's crash, shield their eyes from the lightning, and get covered in Confetti Storm.

## Build list (after the previews are signed off)
1. Victory length and camera hooks: each victory's length (win screen and Locker), camera shake,
   dip and tilt, the runner-up reactions, and a stand-in block in the Locker.
2. Pose tools: keyframes that also move the whole body (jumps, flips, hovering), and props welded
   to the hands.
3. The Epic and Exclusive set: Hero Landing, Confetti Storm, Windmill, Katana, Trophy Lift.
4. The Legendary set: Podium Rise, Thunderstruck, Throne, Meteor Touchdown.
5. The Iridescent set: Supernova, Rift.
6. Catalog: remove the old victories and swap owners to the new ones; level 20 gives Trophy Lift.
