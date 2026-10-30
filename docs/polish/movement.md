# Movement: wall-run chains, landing, momentum, animations

Owner: movement agent. Touches `client/Sprint`, `Slide`, `WallRun`, `AirMomentum`,
`GroundMomentum`, `MoveState`, `Knockback`, `CoyoteJump`, `SlidePose`, `AnimationBuilder` and
`Config.Sprint/Slide/WallRun/Momentum/AirMomentum/Jump/Knockback`. **Start with a design talk;
do not rewrite before the owner agrees on the model.** Every change shifts what the maps can
reach (see `maps.md`).

## What the owner reports
- Wall-run jump chains across big gaps are very hard to make.
- Momentum feels like being sped up, not carrying real momentum.
- Landing feels off.
- Several moves need animations, and the existing ones are only seen by the local player.

## What the code does now
- Ground speed is `Humanoid.WalkSpeed` (18, 20 for It; sprint x1.7 is about 31 and 34), applied
  instantly: no acceleration, no friction.
- "Momentum" is a stored speed number re-applied every frame: `AirMomentum` sets the velocity each
  step, `GroundMomentum` drives a `LinearVelocity`. Direction turns at 1080 degrees per second
  (effectively instant); letting go of the keys drops it at once; gains come from formulas
  (`FallGain`, `LandCarry`), not the real velocity.
- Moves hand speed to each other through `MoveState` fields (`airVelocity`, `landVelocity`,
  `groundVelocity`, `groundSkid`, `launchTime`). Each seam can lose or add speed.
- Wall jump: up `JumpUp` 51.4, at least 20 degrees off the wall, run speed kept, catching the next
  wall needs it within `Reach` 2.2. In the air about 0.5 to 0.8 s at about 30 studs/s, so an 18 to
  22 stud gap needs you to look almost straight across with perfect timing; chains realistically
  cover walls under about 10 studs apart. The maps' wall-run alleys are 18 to 22 wide.
- Slide, crouch and wall-run poses are built at runtime
  (`AnimationClipProvider:RegisterAnimationClip`), so only your own client can play them; other
  players show the default animations.

## Tasks, in order
1. **Design session (no code).** Agree with the owner, using clickable questions: how heavy
   running should feel (instant versus ramped), what carries (real velocity versus stored speed),
   what a landing should do, what wall jumps should reach. Write the answers to
   `docs/polish/notes/movement-model.md`.
2. **Wall-jump math tool.** A Lune script that simulates a wall jump flight from the `Config`
   values and prints the widest gap crossable for a range of entry speeds and look angles, so
   changes are checked on paper. Use it to propose the options: more flight (`JumpUp`, lower
   gravity for a moment after a wall jump), a longer catch reach for a short window after
   jumping, a small steer assist toward a wall you are looking at, or leaving big gaps as a
   separate move.
3. **Landing.** Define the landing rule with the owner (which parts of real velocity carry, what
   the drop adds, what a held slide key adds), implement it, add a landing camera dip and a
   landing animation.
4. **Velocity model prototype** behind `Config.Movement.Model` ("Classic" or "Controller"), in
   steps, each shippable alone:
   a. ground acceleration and deceleration (a controller that drives velocity toward the wish
      velocity with `GroundAccel` and `GroundFriction`),
   b. air acceleration with a speed cap along the wish direction,
   c. fold `GroundMomentum` and `AirMomentum` into it; moves become impulses and states;
      remove the `MoveState` hand-off fields.
   Dev panel sliders for every new number, and a debug readout of velocity versus wish.
5. **Animations for everyone.** The local client sets a `MoveAnim` attribute on its character
   (Slide, Crouch, WallRun, AirSlide, Landing, Knockback, Launch, Frozen); each client plays the
   matching pose locally on that character (`AnimationBuilder`). Missing poses to add: knockback,
   landing, launch, frozen, eliminated, air slide. No uploads needed.
6. **Retune Config** after the owner's feel tests; hand the final numbers to the maps agent.

## Decisions for the owner
- Task 1's answers decide everything else.
- Whether big wall-run gaps should be makeable by chaining or need their own move.

## What the owner tests
Wall-run chains across the Rooftop District alleys and the Metro works gap; landings from
different heights with and without the slide key; stopping and turning at speed; seeing another
player slide and wall run.

## Done when
The owner signs off the feel in each situation above, the dev panel exposes the new numbers, and
mapcheck's constants match `Config`.
