# Ultimate Tag: guide for AI agents

A simple Roblox tag game with a classic studded look. Code lives in files and syncs into Studio with Rojo.

## Style rules
- **Studded, simple, classic** for gameplay maps: Plastic material, bright solid colors, `TopSurface = Studs` / `BottomSurface = Inlet`. No realistic materials.
- **The lobby** is vibrant, flat-shaded low-poly (meshes from Blender with one palette texture), matching the reference art.
- **Lighting** (in `default.project.json`, Rojo-managed) is bright and saturated: ShadowMap, a ColorCorrection boost, soft Bloom, light Atmosphere. Simple white speed trails are the only other effect.
- Keep it simple. Prefer one small module per feature over big scripts.

## Layout (Rojo: `default.project.json`)
| Folder | Lands in Studio as | What goes there |
| --- | --- | --- |
| `src/shared/` | `ReplicatedStorage.Shared` | `Config.luau` (all tunables) and modules used by both sides |
| `src/server/` | `ServerScriptService.Server` | `init.server.luau` entry point plus one ModuleScript per service |
| `src/client/` | `StarterPlayerScripts.Client` | `init.client.luau` entry point plus one ModuleScript per UI or feature |
| `src/tools/` | `ServerStorage.Tools` | Studio-only tools: `SetupLobby` (sets up an imported lobby) and its generated `LobbyData` |
| (none) | `Workspace.Lobby` | the lobby island. **Not managed by Rojo**: it lives only in the place file (see Lobby below) |
| `src/maps/` | `ServerStorage.Maps` | round maps, one folder per map (see Maps below); loaded into `Workspace.ActiveMap` one at a time |

## Maps
Each map is a folder in `src/maps/<MapName>/`:
- `init.meta.json` makes it a `Model` with attributes `DisplayName`, `MinPlayers`, `MaxPlayers` (the player counts it suits: its size tier) and `InRotation` (false keeps it out of games).
- Pieces are `*.model.json` files, one per part or model, in the studded plastic style. Don't put a `name` field in a top-level model file (the file name is the name).
- A `Spawns/` folder of invisible, non-colliding, anchored parts: where players are placed at the start of a round. Have at least as many as the map's `MaxPlayers` if you can (they're reused if not).
- Maps are built around the origin (the lobby is far away at X=2000).
- Place parts with `CFrame`, never `Position`: `"CFrame": { "CFrame": { "position": [x, y, z], "orientation": [[1,0,0],[0,1,0],[0,0,1]] } }`. `Position` only works during live sync and is lost in the built `.rbxlx`, so everything loads at the origin.
- To add a map, copy a placeholder folder, change its attributes and pieces. MapService picks it up automatically.

Studio-owned maps: real maps are built in Studio and live only in the place file, next to the Rojo ones in `ServerStorage.Maps` (the project sets `$ignoreUnknownInstances` there so Rojo leaves them alone). Same contract: a Model with the attributes above and a `Spawns` folder. To edit one by hand, drag it into Workspace, change it, and drag it back.

Current maps:
- `SmallBox` (2-6 players, 60x60), `MediumBox` (5-14, 120x120), `LargeBox` (12-50, 220x220): placeholder arenas, a studded floor with four walls and a ring of spawn points. Real maps come later.
- `TestGround` (`InRotation` false): the movement test map, loaded in Sandbox mode. Its pieces:
  - `Baseplate.model.json`: 512x4x512 green studded baseplate, top at Y=0. `SpawnLocation.model.json`: white spawn pad at the center.
  - `TestCourse.model.json`: five yellow steps up to three raised platforms (gaps of 6 and 11 studs).
  - `SlideBar.model.json`: red bar at X=30, Z=-20 (underside Y=4.2) with an invisible `StandBlocker` (attribute `SlideBlocker`) under it: you have to slide or crouch under.
  - `VaultWall.model.json`: orange wall 3 tall at X=-30, Z=-20 (auto vault). `MantleLedge.model.json`: purple block 9 tall at X=-30, Z=-55 (mantle).
  - `BounceWalls.model.json`: two teal walls 30 tall at X=54 and X=66, Z=-50 (wall run, wall climb).
  - `ParkourCourse.model.json`: from the reference video, at X=120 heading -Z: climb tower, wall-run corridor, landing platform, three stepping stones, platform, drop, steps.
- Any part with the `SlideBlocker` attribute blocks standing players but not sliding or crouching ones (CollisionGroups also handles maps loaded later).

## Lobby
The lobby is a low-poly tropical island made in Blender (`tools/blender/make_lobby.py`) and imported into Studio once. After that, **Studio owns it**: it lives in the place file (save the place, and publish to keep it safe), you edit it freely in Studio, and Rojo never touches `Workspace.Lobby`.
- Layout: `Workspace.Lobby/<Category>/<Object>` Models (Island, Water, Horizon, Nature, Props, Landmarks, Lounge_Zone, UI_Assets, Shop_Structure, Lighthouse), each with its pivot at its base, plus `LobbySpawn` and an invisible `Boundary` ring. One mesh per object (palette texture), `*_Glow` parts are Neon, decorations don't collide, palms have invisible trunk colliders.
- Setting up (or redoing) the lobby: run the generator from the repo root (writes `assets_src/lobby/UltimateTagLobby.fbx` and `src/tools/LobbyData.luau`; run `stylua src` afterwards), then in Studio **Import 3D** the FBX and run `require(game.ServerStorage.Tools.SetupLobby)()` in the command bar, then save. SetupLobby fixes the import's scale/rotation/position with four marker cubes (island center goes to `Config.Lobby.Position`), organizes it, sets collision, and adds sign text (SurfaceGuis), Seats, prompts, the leaderboard screen and the wheel's spin data. Re-running on a new import replaces the old lobby (manual Studio edits are lost then).
- Working parts find their pieces by CollectionService tag, so they keep working when moved: `LobbyLeaderboard` (screen part), `RewardWheel` (wheel part, with `SpinAxis`/`SpinCenter`/`Segments`/`Angle` attributes in its own space), `RewardWheelPrompt`, `AvatarShopPrompt` (shows its `Message` attribute).

## Art pipeline (Blender)
Blender 5 is installed (`blender` on the PATH). Generator scripts in `tools/blender/` build models in code; run them with `blender --background --python <script> -- <out_dir> [preview_dir]`.
- `make_lobby.py`: the lobby island (see Lobby). 118 objects, one mesh each (about 36k triangles total), colored by a one-row palette texture (`LobbyPalette.png`, flip-proof); each object has its own mesh named after it (so imported pieces are named predictably); glow pieces separate; sign text is data, not mesh. Studs, Z up, front faces -Y. Writes `assets_src/lobby/UltimateTagLobby.blend`/`.fbx`, `src/tools/LobbyData.luau`, and with a preview dir, renders (`assets_src/lobby/previews/`). Also runs from Blender's Text Editor.
- `make_character.py`, `smooth_body.py`: earlier character experiments (unused).

## Conventions
- Every tunable number or name goes in `src/shared/Config.luau`. Never hard-code it in a service.
- A new feature means a new module, required and started from the matching `init.*.luau`.
- Luau, `--!strict` where practical, formatted with StyLua (tabs, 100 columns).

## Checks (run before every commit)
```
export PATH="$HOME/.rokit/bin:$PATH"
stylua src && selene src && lune run tools/check-syntax.luau && rojo build -o build/check.rbxlx
```
**Never build to `UltimateTag.rbxlx`**: the lobby exists only in that place file, so rebuilding it from the project would delete the lobby. `build/` is git-ignored.

## Workflow
- After each change: update this file (layout, map, features, changelog) and the README if needed, run the checks, commit, then `git push`.
- Commit message format: `area: what changed` (for example `map: add obstacle course`).
- GitHub: https://github.com/EvanLowther/UltimateTag (private). The `.rbxlx` file is built by Rojo and git ignores it.

## Features
**Game flow (0.26.0).** `Config.Game.Mode = "Elimination"`: players wait in the lobby; with `MinPlayers` (Studio: `StudioMinPlayers`) a `LobbyCountdown` starts, then a game. Each round MapService picks a map for the number of players still in, everyone is placed on its spawn points, the game mode assigns roles, everyone is frozen for `IntroTime` (Its for `ItHeadStart` longer), then the `RoundTime` timer runs. When it ends the mode decides who is eliminated; they go back to the lobby and spectate (Q/E to switch). Rounds continue on new maps until one player is left: they win (+1 Win) and everyone returns to the lobby. Only It can tag, by left-clicking (a swipe) within `Config.Tag.Range`, and only while a round is Playing. Test with 2+ players in Studio (Test > Clients and Servers > Local Server).
- Game modes live in `src/server/Modes/`. Each has `Name`, `setup(players) -> status text` and `finish(players) -> eliminated`. The first is **Hot Potato** (`Modes/HotPotato.luau`): `EliminateFraction` (about 45%) of players start as It, tagging passes It, whoever is It when time runs out is eliminated. To add a mode, add a module with that shape and point `GameLoop`'s `mode` at it.
- `Config.Game.Mode = "Sandbox"`: the old free-play test mode on TestGround (one It, nothing ends) for movement testing. The dev panel switches modes while the server runs (`GameLoop.setMode`).

| Module | Side | Job |
| --- | --- | --- |
| `shared/Config.luau` | both | All tunables: tag range, freeze time, speeds, colors, font |
| `shared/BodyRig.luau` | both | Builds the character body: a smooth rounded cartoon person (Crab Game style) from round shapes. Cylinder limbs turned upright through their attachments (joint frames keep standard axes), ball joints, ball head and hands, face (eyes, pupils, mouth), hair, tracksuit stripes, zipper and soles welded on as details. Sizes and colors in `Config.Body`. |
| `shared/Remotes.luau` | both | The RemoteEvents in `ReplicatedStorage.Remotes`: `setup()` on the server, `get(name)` anywhere. `TagSwing` (client to server), `TagSwingPlayed` (server to all clients), `Notify` (server to one client), `DevCommand` (dev panel, both ways). |
| `shared/GameState.luau` | both | `Phase`, `TimeLeft`, `Round`, `AliveCount`, `Status` as ReplicatedStorage attributes (plus `Winner` during Victory). Server writes, clients read and listen. |
| `server/Roles.luau` | server | `Role` attribute on each Player (`"It"` / `"Runner"` / nil). Applies speed, freeze and the red It highlight, again on respawn. |
| `server/TagService.luau` | server | Handles the `TagSwing` remote: checks the sender is It, not frozen and off `Config.Tag.Cooldown`, tells all clients to play the swipe (`TagSwingPlayed`), and tags the nearest Runner within `Config.Tag.Range`. |
| `server/Sandbox.luau` | server | Sandbox mode only: players join as Runners, keeps one player as It |
| `server/Avatar.luau` | server | Makes the `StarterCharacter` (currently the classic 2012 block R15 rig, `Config.Body.Enabled = false`): the BodyRig (with Roblox's standard Animate script borrowed from a classic rig), or the classic 2012 block rig if `Config.Body.Enabled` is off. Respawns any non-R15 character. |
| `server/CollisionGroups.luau` | server | Registers the `SlideBlocker` / `Sliding` collision groups and puts `SlideBlocker` parts in their group |
| `server/GameLoop.luau` | server | The game state machine: Lobby, Countdown, rounds (Intro, Playing, Results), Victory. Or the Sandbox in Sandbox mode. |
| `server/Participants.luau` | server | Who is in the game: `InGame` / `Alive` player attributes, keeps `AliveCount` updated. |
| `server/MapService.luau` | server | Map catalog from `ServerStorage.Maps`: `choose(playerCount, lastMap)` by size tier, `load`/`unload` as `Workspace.ActiveMap`, `spawnPoints`. |
| `server/Modes/HotPotato.luau` | server | The Hot Potato game mode (see Game flow). |
| `client/Spectate.luau` | client | While a game is on and you're not in it, the camera follows a living player; Q/E or arrows switch. |
| `server/WinsStore.luau` | server | Lifetime wins: loads them into the Wins column, `addWin` saves (DataStore `Wins_v1`) and updates the top list (OrderedDataStore `TotalWins_v1`), `top(n)` for the leaderboard. Without data store access it keeps working for the session. |
| `server/LobbyLeaderboard.luau` | server | Fills the `LobbyLeaderboard` screen with `WinsStore.top` every `Config.Lobby.LeaderboardRefresh` seconds. |
| `server/RewardWheel.luau` | server | The `RewardWheelPrompt` spins the `RewardWheel` part for everyone, lands on a random prize (`Config.Lobby.WheelPrizes`), tells the player; one spin per `WheelCooldownHours`, saved when possible. |
| `client/Notify.luau` | client | Short on-screen messages from the `Notify` remote, and from ProximityPrompts with a `Message` attribute. |
| `server/Leaderstats.luau` | server | `Wins` (lifetime, from WinsStore) / `Tags` columns in the player list. `add` and `set`. |
| `client/Sprint.luau` | client | Hold `Config.Sprint.Key` (Left Shift) to run `Config.Sprint.Multiplier` times faster, with a small field-of-view boost. Client-side for instant feel. |
| `client/Slide.luau` | client | The C key. Sprinting on the ground: slide (boost unless within `DeadSlideTime` = dead slide; uses your landing speed within `LandingGrace`). Moving fast in the air: air slide (no boost, slow-down starts on landing). Otherwise: crouch at `CrouchSpeed` (idle pose, crouch-walk cycle while moving; height worked out from leg lengths so feet stay on the floor), low enough for slide bars, no jumping under a ceiling. A slide that runs out with C held becomes a crouch. Can't stand up under a ceiling; jumping out of a slide keeps its speed. |
| `client/SlidePose.luau` | client | The slide and crouch animations: builds keyframed animations from `Config.Slide.Poses` (Drop, Slide, Lunge, Crouch from the reference frames, plus CrouchWalk) and plays them through the Animator. Also the hip sink and camera dip. Registered on the client only, so other players don't see it yet; replace with an uploaded Animation before multiplayer. |
| `client/Vault.luau` | client | Automatic hop (the only vault): sprinting (or fast), on the ground or mid-jump, into an obstacle `MinHeight`-`MaxHeight` tall. Thin (up to `MaxDepth`): arc over it. Deep: arc up onto it. Keeps your speed, no key, no pause. |
| `client/Mantle.luau` | client | Automatic: in the air, moving toward a ledge within reach and taller than `Config.Vault.MaxHeight` above the floor in front of it (lower ones are the vault's), once the jump has nearly peaked (`MaxRiseSpeed`) or while falling: pull up (`UpTime`) then over the edge (`OverTime`), stopping at the top. Mantle Boost: a fresh jump press inside `BoostWindowStart`-`BoostWindowEnd` (seconds into the climb) launches you up and over (`BoostForward`/`BoostUp`); pressing early uses up the try. |
| `client/AirMomentum.luau` | client | In the air with no move running, owns sideways velocity: keeps your speed (wall runs, slides, vaults carry through), keys turn your path (`TurnRate`), steering back brakes. Records the speed you land with for slides. |
| `client/WallRun.luau` | client | Automatic when airborne and fast (sprinting or `MinEntrySpeed`) with a wall within `Reach` ahead, beside or diagonally (nearest wins): heading within `ClimbAngle` of straight at a tall wall = Climb: hop up the face (`HopSpeed`/`HopTime`) then Cling (hold on, slide slowly, `ClingTime`); jump while clinging to hop again (up to `MaxHops`); reaching the top = Hang (forward or jump climbs over through `Mantle.climbToward`, back drops); anything else not moving away from it = WallRun (along it, rise then sink, camera leans away). Jump kicks off the wall. Short walls are left to Mantle. |
| `client/LandingRoll.luau` | client | Landing from a big drop (`MinFallSpeed`) while moving: a forward roll that keeps your speed. First person dips the camera instead of spinning. Holding slide on landing slides instead. |
| `client/SpeedTrails.luau` | client | White trails on hands and feet when fast (`MinSpeed`) or during a move (`Moves`); feet only in first person. Client-only. |
| `client/MoveState.luau` | client | The one source of movement state: `busy` (one move at a time), `airVelocity` (speed carried through the air), `landVelocity`/`landTime` (speed you last landed with), `parts()`, `isGrounded()`, `flat()`, `drive()`, `launch()` (shared vault/mantle throw, sets `launchTime`), `cameraYaw()`/`yawChange()`/`turnFlat()` (look coupling). New moves read these instead of re-checking. |
| `client/Crouch.luau` | client | The only code that changes HipHeight (and CameraOffset in third person; FirstPersonBody owns it in first person). Moves call `Crouch.set(humanoid, factor, seconds, cameraDip)`. |
| `client/AnimationBuilder.luau` | client | Builds keyframed animations from pose tables (degrees per R15 body part) and loads them on the Animator. `make(keys, partial)`: each key can set `ease` ("In", "Out", "InOut"); with `partial`, unlisted parts get weight 0 so the animation underneath keeps moving them. `mirror()` flips a pose left/right. Client-only registration. |
| `client/RunPace.luau` | client | Every frame sets Roblox's WalkAnim/RunAnim pace from your ground speed, clamped (`Config.RunPace`), so mantles, boost landings or crouches can't leave the run animation stuck too fast. |
| `client/Upright.luau` | client | Turns off the FallingDown and Ragdoll humanoid states (no toppling) and `AutomaticScalingEnabled` (otherwise Animate speeds up the run animation whenever a move lowers the hips). The server also sets it on the StarterCharacter. |
| `client/MantleBoostUI.luau` | client | The Mantle Boost timing indicator: brackets close on a center ring and a marker drops in; cyan when the window is open, check on success, grey on an early press. |
| `client/FaceCamera.luau` | client | Facing. Third person: Roblox turns you toward your running (`AutoRotate`). First person: face the camera. A move can set `MoveState.faceDirection` and the body turns smoothly to it (`Config.Camera.TurnRate`). |
| `client/CameraKick.luau` | client | Camera feel layered on the normal camera each frame: `kick(roll, pitch, duration)` short jolts, `lean(roll)` a held roll (wall running). |
| `client/ViewMode.luau` | client | First or third person. Starts in third person like the reference video (`Config.Camera.StartFirstPerson = false`); V toggles first person for testing (`AllowToggle`). |
| `client/FirstPersonBody.luau` | client | First person: shows your legs (and their details) only, keeps face, hair and other details hidden (head and torso hidden; the blocky torso fills the screen from above), hides your own highlight on your screen, and moves the camera with your head via `CameraOffset`, `BodyForward` studs ahead. |
| `client/Viewmodel.luau` | client | First-person arms: classic yellow blocks (`ClassicArm`/`ClassicHand`) with the classic avatar, or the rounded body's forearm and hand scaled by `Config.Viewmodel.Scale`, attached to the camera, posed per move from `Config.Viewmodel.Poses` (Idle with run swing, Air, Slide, Crouch, Vault, MantleGrab to MantlePush). |
| `client/TagSwing.luau` | client | Left click (or R2) while It: plays the swipe at once, jabs the first-person arm, fires `TagSwing`. Plays other players' swipes when `TagSwingPlayed` arrives, so everyone sees them. |
| `client/Hud.luau` | client | Status line, timer / round / players left, and banners: YOU ARE IT!, RUN!, ELIMINATED, YOU WIN!, "<name> wins!". |
| `shared/DevAccess.luau` | both | `isDeveloper(player)`: everyone in Studio, plus `Config.DevPanel.UserIds` in live servers (off entirely with `Config.DevPanel.Enabled = false`). |
| `server/DevCommands.luau` | server | The dev panel's server side: handles `DevCommand` (checks DevAccess every time). Game flow (SetMode, StartNow, Skip, SetTimeLeft, SetRoundTime, SetRole, Freeze, Unfreeze, Respawn), maps (ListMaps, PlayMap, NextMap, UnloadMap), SetTunable (only values in `Config.DevPanel.Tunables`). Replies with Notify. |
| `client/DevPanel/` | client | The dev panel (` key), Studio and listed developers only. `init` builds the window (drag by the title, frees the mouse in first person) and tabs: `GameTab`, `MapsTab`, `MovementTab` (sliders from `Config.DevPanel.Tunables`, applied to this client's Config and the server's; "Copy changes" prints them for Config.luau), `DebugTab`. `DebugTools`: fly + noclip (holds `MoveState.busy = "Fly"`), teleport key, movement readout, spawn point display. `Widgets`: the UI pieces. |

Rules of thumb:
- Testing tools go in the dev panel: a new server command is a handler in `server/DevCommands.luau` (it already checks access), a new tunable is a line in `Config.DevPanel.Tunables`.
- Server owns all game state. Clients read attributes and ask the server through RemoteEvents in `shared/Remotes.luau` (add new names to its list).

## Changelog
- 0.29.0: Tried a container-yard map (Tag Island Port, 100x100 then 250x250) and removed it: containers are too small for our moves (wall runs cover about 48 studs, Mantle Boost about 38). Rojo now leaves Studio-made maps in `ServerStorage.Maps` alone.
- 0.28.0: Dev panel (` key, Studio only): switch Elimination/Sandbox live, start now, skip or set timers, set your role, freeze; load any map or pick the next round's; live movement sliders with a copyable change list; movement readout, fly + noclip, teleport key, spawn points. GameLoop can switch modes and skip timers; MapService has a catalog and a next-map override; GameState has `Mode`.
- 0.27.0: New lobby island to match the reference art (Blender, one mesh per object, palette texture, faceted see-through ocean, distant islands, no figures), imported once and owned by Studio, set up by `ServerStorage.Tools.SetupLobby`. Working parts: live all-time leaderboard (saved lifetime wins), spinning daily reward wheel, shop prompt, bench seats. Vibrant lighting (ColorCorrection, Bloom, Atmosphere). Checks now build to `build/check.rbxlx`.
- 0.26.1: Lobby island model generated in Blender (`tools/blender/make_lobby.py`, 865 named pieces), not yet imported into the game.
- 0.26.0: Game flow: lobby (X=2000) with auto countdown, elimination rounds on maps picked by player count (ServerStorage.Maps; SmallBox, MediumBox, LargeBox placeholders), Hot Potato mode (about 45% start as It, Its at the timer are eliminated), spectating with Q/E, last player standing wins. HUD shows timer, round, players left and banners. Sandbox mode kept on TestGround. Tagging only during a round.
- 0.25.0: Tagging is a left-click swipe for It (server checks range, cooldown and freeze), with a swipe animation everyone sees and a first-person arm jab. Replaces automatic touch tagging. First RemoteEvents (`shared/Remotes.luau`).
- 0.24.0: Slide looks like the reference video: feet first with straight legs, body leaned back about 60 degrees, one arm up, quicker drop and recovery. Bar swinging removed entirely; the course bars became stepping stones.
- 0.23.4: Only the auto vault handles low obstacles: Mantle skips ledges within vault height of the floor (that pull-up looked like the old space vault), and the auto vault also works mid-jump.
- 0.23.3: RunPace: the walk and run animations' pace follows your ground speed every frame (clamped), fixing the sped-up run after mantles and boost landings.
- 0.23.2: Fix: the run animation played too fast after crouching or sliding (Animate read the lowered hip height as short legs). AutomaticScalingEnabled is now off.
- 0.23.1: Crouch cuts you to crouch speed at once, the crouch-walk plays at a steady pace, and standing up restores your speed from your role and sprint (`Sprint.targetSpeed()`) instead of a saved value.
- 0.23.0: Crouch has a real idle pose and a crouch-walk cycle, and its height comes from the leg lengths and knee angles so the feet stay on the floor (no more clipping). Replaces `CrouchHipFactor`.
- 0.22.1: Wall-climb hops about 12 studs each (measured from the reference video), and rising past the top edge in one frame still catches the ledge.
- 0.22.0: Wall climb is now jump-up-and-hold like the reference video: hop up the wall, cling to it, jump to hop higher (3 hops), hang at the top and climb over.
- 0.21.2: Wall run animation: body tilts away from the wall so the feet run on it, arms pump instead of reaching into the wall, and you're held `RunGap` studs from the wall.
- 0.21.1: Wall run starts much more reliably: walls are detected ahead, beside and diagonally (`Reach` 2.2), no dead zone between climb and run, `MinEntrySpeed` 18.
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
