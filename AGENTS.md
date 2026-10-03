# Ultimate Tag: guide for AI agents

A simple Roblox tag game with a classic studded look. Code lives in files and syncs into Studio with Rojo.

## Style rules
- **Studded, simple, classic.** Plastic material, bright solid colors, `TopSurface = Studs` / `BottomSurface = Inlet`. No realistic materials, no post-processing, no fancy effects (simple white speed trails are the one exception).
- Keep it simple. Prefer one small module per feature over big scripts.

## Layout (Rojo: `default.project.json`)
| Folder | Lands in Studio as | What goes there |
| --- | --- | --- |
| `src/shared/` | `ReplicatedStorage.Shared` | `Config.luau` (all tunables) and modules used by both sides |
| `src/server/` | `ServerScriptService.Server` | `init.server.luau` entry point plus one ModuleScript per service |
| `src/client/` | `StarterPlayerScripts.Client` | `init.client.luau` entry point plus one ModuleScript per UI or feature |
| `src/map/` | `Workspace.Map` | map pieces as `*.model.json` files (one file per part or model) |

## Map
- `src/map/Baseplate.model.json`: 512x4x512 green (75,151,75) studded plastic baseplate, top at Y=0.
- `src/map/SpawnLocation.model.json`: white studded 8x8 spawn pad at the center, no forcefield.
- `src/map/TestCourse.model.json`: movement test course heading -Z from spawn. Five yellow steps up to three raised platforms (blue, red, green; top at Y=10). The gap after the blue one is 6 studs (walk jump), the gap after the red one is 11 studs (needs a sprint jump).
- `src/map/SlideBar.model.json`: red bar on two yellow posts at X=30, Z=-20 (underside at Y=4.2). Too low to walk under, so you have to slide. The posts are 22 studs apart; run at it from +Z. An invisible `StandBlocker` part fills the space under the bar (attribute `SlideBlocker`), because a character's collision box doesn't reach its head. Sliding characters pass through it.
- `src/map/VaultWall.model.json`: orange wall 3 tall, 2 thick, 20 wide at X=-30, Z=-20. Sprint into it from +Z and you hop it automatically.
- `src/map/MantleLedge.model.json`: purple block 9 tall at X=-30, Z=-55. Too high to jump onto, so jump at it to mantle.
- `src/map/BounceWalls.model.json`: two teal walls 30 tall, 12 studs apart (X=54 and X=66, Z=-50). Wall run along them or climb them; jump to kick off.
- `src/map/ParkourCourse.model.json`: course built from the parkour reference video, at X=120 heading -Z. Blue climb tower (14 tall) -> two red wall-run walls (22 tall, 16 apart, 14-stud drop between) -> yellow landing platform (top Y=12) -> three swing bars at Y=17 -> orange platform (top Y=10) -> drop -> white steps (2 to 8 tall).
- Any part with the `SwingBar` attribute (a cylinder along its X axis) is a bar you can swing on.
- Any part with the `SlideBlocker` attribute blocks standing players but not sliding ones. Use it for every slide-under obstacle.
- To add a map piece, add another `*.model.json` in `src/map/`. Use the same studded plastic style.
- Place parts with `CFrame`, never `Position`: `"CFrame": { "CFrame": { "position": [x, y, z], "orientation": [[1,0,0],[0,1,0],[0,0,1]] } }`. `Position` only works during live sync and is lost in the built `.rbxlx`, so everything loads at the origin.

## Conventions
- Every tunable number or name goes in `src/shared/Config.luau`. Never hard-code it in a service.
- A new feature means a new module, required and started from the matching `init.*.luau`.
- Luau, `--!strict` where practical, formatted with StyLua (tabs, 100 columns).

## Checks (run before every commit)
```
export PATH="$HOME/.rokit/bin:$PATH"
stylua src && selene src && lune run tools/check-syntax.luau && rojo build -o UltimateTag.rbxlx
```

## Workflow
- After each change: update this file (layout, map, features, changelog) and the README if needed, run the checks, commit, then `git push`.
- Commit message format: `area: what changed` (for example `map: add obstacle course`).
- GitHub: https://github.com/EvanLowther/UltimateTag (private). The `.rbxlx` file is built by Rojo and git ignores it.

## Features
**Sandbox (0.3.0).** No rounds, timer or wins yet. This is a free-play test mode for building mechanics. Everyone is a Runner and one player is always It. It tags a Runner by getting within `Config.Tag.Range`. The tagged player becomes It and is frozen briefly, which also stops instant tag-backs. If It leaves, someone else becomes It. Test with two or more players (Studio: Test tab > Clients and Servers > Local Server).

| Module | Side | Job |
| --- | --- | --- |
| `shared/Config.luau` | both | All tunables: tag range, freeze time, speeds, colors, font |
| `shared/BodyRig.luau` | both | Builds the character body: a smooth rounded cartoon person (Crab Game style) from round shapes. Cylinder limbs turned upright through their attachments (joint frames keep standard axes), ball joints, ball head and hands, face (eyes, pupils, mouth), hair, tracksuit stripes, zipper and soles welded on as details. Sizes and colors in `Config.Body`. |
| `shared/GameState.luau` | both | Status text as a ReplicatedStorage attribute. Server writes, clients read and listen. |
| `server/Roles.luau` | server | `Role` attribute on each Player (`"It"` / `"Runner"` / nil). Applies speed, freeze and the red It highlight, again on respawn. |
| `server/TagService.luau` | server | Heartbeat distance check from It to Runners. Performs the tag. |
| `server/Sandbox.luau` | server | Free-play setup: players join as Runners, keeps one player as It |
| `server/Avatar.luau` | server | Makes the `StarterCharacter` (currently the classic 2012 block R15 rig, `Config.Body.Enabled = false`): the BodyRig (with Roblox's standard Animate script borrowed from a classic rig), or the classic 2012 block rig if `Config.Body.Enabled` is off. Respawns any non-R15 character. |
| `server/CollisionGroups.luau` | server | Registers the `SlideBlocker` / `Sliding` collision groups and puts `SlideBlocker` parts in their group |
| `server/Leaderstats.luau` | server | `Wins` / `Tags` columns in the player list (Wins unused until rounds return) |
| `client/Sprint.luau` | client | Hold `Config.Sprint.Key` (Left Shift) to run `Config.Sprint.Multiplier` times faster, with a small field-of-view boost. Client-side for instant feel. |
| `client/Slide.luau` | client | The C key. Sprinting on the ground: slide (boost unless within `DeadSlideTime` = dead slide; uses your landing speed within `LandingGrace`). Moving fast in the air: air slide (no boost, slow-down starts on landing). Otherwise: crouch at `CrouchSpeed`, low enough for slide bars, no jumping under a ceiling. A slide that runs out with C held becomes a crouch. Can't stand up under a ceiling; jumping out of a slide keeps its speed. |
| `client/SlidePose.luau` | client | The slide and crouch animations: builds keyframed animations from `Config.Slide.Poses` (Drop, Slide, Lunge, Crouch from the reference frames, plus CrouchWalk) and plays them through the Animator. Also the hip sink and camera dip. Registered on the client only, so other players don't see it yet; replace with an uploaded Animation before multiplayer. |
| `client/Vault.luau` | client | Automatic hop: sprinting (or fast) on the ground into an obstacle `MinHeight`-`MaxHeight` tall. Thin (up to `MaxDepth`): arc over it. Deep: arc up onto it. Keeps your speed, no key, no pause. |
| `client/Mantle.luau` | client | Automatic: in the air, moving toward a ledge within reach, once the jump has nearly peaked (`MaxRiseSpeed`) or while falling: pull up (`UpTime`) then over the edge (`OverTime`), stopping at the top. Mantle Boost: a fresh jump press inside `BoostWindowStart`-`BoostWindowEnd` (seconds into the climb) launches you up and over (`BoostForward`/`BoostUp`); pressing early uses up the try. |
| `client/AirMomentum.luau` | client | In the air with no move running, owns sideways velocity: keeps your speed (wall runs, swings, slides carry through), keys turn your path (`TurnRate`), steering back brakes. Records the speed you land with for slides. |
| `client/WallRun.luau` | client | Automatic when airborne and fast at a wall: heading straight at a tall wall = Climb (run up it, slowing over `ClimbTime`), reaching the top = Hang (forward or jump climbs over through `Mantle.climbToward`, back drops); alongside a wall = WallRun (along it, rise then sink, camera leans away). Jump kicks off the wall. Short walls are left to Mantle. |
| `client/BarSwing.luau` | client | Jump up to a `SwingBar` part to grab it; pendulum swing (hold forward to pump), jump releases with momentum (`ReleaseBoost`), slide key drops. |
| `client/LandingRoll.luau` | client | Landing from a big drop (`MinFallSpeed`) while moving: a forward roll that keeps your speed. First person dips the camera instead of spinning. Holding slide on landing slides instead. |
| `client/SpeedTrails.luau` | client | White trails on hands and feet when fast (`MinSpeed`) or during a move (`Moves`); feet only in first person. Client-only. |
| `client/MoveState.luau` | client | The one source of movement state: `busy` (one move at a time), `airVelocity` (speed carried through the air), `landVelocity`/`landTime` (speed you last landed with), `parts()`, `isGrounded()`, `flat()`, `drive()`, `launch()` (shared vault/mantle throw, sets `launchTime`), `cameraYaw()`/`yawChange()`/`turnFlat()` (look coupling). New moves read these instead of re-checking. |
| `client/Crouch.luau` | client | The only code that changes HipHeight (and CameraOffset in third person; FirstPersonBody owns it in first person). Moves call `Crouch.set(humanoid, factor, seconds, cameraDip)`. |
| `client/AnimationBuilder.luau` | client | Builds keyframed animations from pose tables (degrees per R15 body part) and loads them on the Animator. `make(keys, partial)`: each key can set `ease` ("In", "Out", "InOut"); with `partial`, unlisted parts get weight 0 so the animation underneath keeps moving them. `mirror()` flips a pose left/right. Client-only registration. |
| `client/Upright.luau` | client | Turns off the FallingDown and Ragdoll humanoid states so vaults and slides don't make you topple. |
| `client/MantleBoostUI.luau` | client | The Mantle Boost timing indicator: brackets close on a center ring and a marker drops in; cyan when the window is open, check on success, grey on an early press. |
| `client/FaceCamera.luau` | client | Facing. Third person: Roblox turns you toward your running (`AutoRotate`). First person: face the camera. A move can set `MoveState.faceDirection` and the body turns smoothly to it (`Config.Camera.TurnRate`). |
| `client/CameraKick.luau` | client | Camera feel layered on the normal camera each frame: `kick(roll, pitch, duration)` short jolts, `lean(roll)` a held roll (wall running). |
| `client/ViewMode.luau` | client | First or third person. Starts in third person like the reference video (`Config.Camera.StartFirstPerson = false`); V toggles first person for testing (`AllowToggle`). |
| `client/FirstPersonBody.luau` | client | First person: shows your legs (and their details) only, keeps face, hair and other details hidden (head and torso hidden; the blocky torso fills the screen from above), hides your own highlight on your screen, and moves the camera with your head via `CameraOffset`, `BodyForward` studs ahead. |
| `client/Viewmodel.luau` | client | First-person arms: classic yellow blocks (`ClassicArm`/`ClassicHand`) with the classic avatar, or the rounded body's forearm and hand scaled by `Config.Viewmodel.Scale`, attached to the camera, posed per move from `Config.Viewmodel.Poses` (Idle with run swing, Air, Slide, Crouch, Vault, MantleGrab to MantlePush). |
| `client/Hud.luau` | client | Status text and the "YOU ARE IT!" / "RUN!" banner |

Rules of thumb:
- Server owns all game state. Clients only read attributes (no RemoteEvents yet; add a `Remotes` setup in `init.server.luau` when one is needed).
- Rounds were removed in 0.3.0 (see git history, `RoundService.luau` in 0.2.0) and will come back once the mechanics are settled.

## Changelog
- 0.21.0: Movement rebuild toward the parkour reference video. Removed: air strafing/look coupling, wall bounce (wall-run kick-off replaces it), the super-glide vault launch. Added: AirMomentum (keeps air speed), automatic hop vault and step-up. Third person by default, body turns toward your running. Bar swing fixed (forgiving grab zone, bars at Y=22). Faster sprint (about 30), mantle, wall run and climb.
- 0.20.0: Moves from the parkour reference video: wall climb with ledge hang and climb-over, wall run with camera lean, bar swing, landing roll, speed trails, and a ParkourCourse to chain them. AnimationBuilder gains looping; Mantle exposes `climbToward`.
- 0.19.0: Back to the classic 2012 R15 block avatar (`Config.Body.Enabled = false`); first-person arms are classic yellow blocks again. The rounded BodyRig and the Blender tools (`tools/blender`, `assets_src`) are kept but unused.
- 0.18.0: New character look (Crab Game style): rounded body from cylinders and balls, cartoon face and hair, orange tracksuit with white stripes, joggers, sneakers. First-person arms match (sleeve, stripe, ball hand).
- 0.17.0: Wall bounce feels physical: a short plant on the wall, then the push; four-beat eased animation (reach, absorb, push, follow-through) with balancing limbs.
- 0.16.2: Fix: bouncing off a wall in front errored (missing `WallPushFront` arm pose). Viewmodel now falls back to Idle with one warning if a pose is missing.
- 0.16.1: Wall bounce animation only moves the limbs touching the wall (by wall side), the rest keep falling naturally. No more T-pose. AnimationBuilder gains partial animations and mirroring.
- 0.16.0: Wall bounce feedback: camera kick, kick-off animation, hit/push sounds, first-person hand planting on the wall. New CameraKick module.
- 0.15.0: Look coupling: air momentum turns with your view while a movement key is held (tap-strafe style), and slides curve with your view.
- 0.14.1: Body always faces where you look (FaceCamera), including third person and during slide, vault and mantle.
- 0.14.0: New character body (BodyRig): slim, realistic proportions in smooth blocks, faceless head, boots, everyone sees it. First-person arms use the same forearm and hand.
- 0.13.1: First person shows legs only, hides your own It highlight locally, smaller viewmodel arms with hands.
- 0.13.0: First person by default (V toggles third person for testing). You can see your torso and legs, the camera follows your head, and block viewmodel arms are posed for each move.
- 0.12.0: Mantle Boost goes about 15 studs further. Air slide (C while moving fast in the air). Crouch (C without sprinting) to get under things slowly; slides that run out with C held become crouches.
- 0.11.0: Mantle Boost (Apex style): a timing window during the climb with an on-screen indicator. Jump in the window to launch up and over; too early and you just climb.
- 0.10.0: Vault is now a launch: hands on the top, then thrown up and out about 25-30 studs. Jumping during a mantle launches you over the top the same way (super glide). Shared `MoveState.launch`.
- 0.9.0: Vault launches you off the far side with a speed boost and hop (super glide style). Slides right after landing keep your air speed, and holding C as you land slides on touchdown. FallingDown/Ragdoll turned off so you stop toppling.
- 0.8.1: Map pieces use `CFrame` instead of `Position`, so they keep their places in the built place file (they were all loading at spawn).
- 0.8.0: Apex-style additions: dead slide (no boost if sliding again within 1.75s), AirStrafe (keep speed and steer in the air), WallBounce (jump off walls mid-air), BounceWalls test map. MoveState is now the shared source for parts, grounded and air velocity.
- 0.7.2: Mantle is automatic when you jump at a ledge (no holding jump); it needs you to be moving toward the ledge.
- 0.7.1: Mantle only grabs near the top of a jump or while falling, so tapping jump and vaulting no longer turn into mantles.
- 0.7.0: Vault (jump while sprinting at a low obstacle, keeps speed) and Mantle (hold jump at a ledge, stops at the top), with VaultWall and MantleLedge test obstacles. Shared move code split out: MoveState, Crouch, AnimationBuilder.
- 0.6.0: Slide animation rebuilt as real keyframed animations played through the Animator (the old joint-rotation approach was overwritten every frame). Stages: drop, slide hold, lunge, crouch, stand.
- 0.5.3: Everyone is the classic 2012 block avatar while testing (`Config.Avatar.UseOwnAvatar = false`).
- 0.5.2: Force R15 bodies for everyone (needed for the slide pose).
- 0.5.1: Slide animation (code-driven R15 pose, no clipping into the ground). Slide bar now blocks standing players with an invisible blocker that sliders pass through.
- 0.5.0: Slide (C while sprinting) and a SlideBar test obstacle.
- 0.4.0: Movement work: Sprint (hold Shift) and a TestCourse map for jump tests.
- 0.3.0: Removed rounds, timer and spawn scatter. Added Sandbox free-play mode for testing mechanics.
- 0.2.1: Rojo serve port changed to 34874 (34872 was clashing with another project).
- 0.2.0: Core tag loop: rounds, It/Runner roles, distance tagging, freeze on tag, Wins/Tags leaderstats, HUD.
- 0.1.0: Project setup (Rojo, rokit, StyLua, Selene, Lune). Green studded baseplate and spawn pad.
