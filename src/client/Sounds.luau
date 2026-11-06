--!strict
-- Every sound in the game, on this client (Config.Sounds; the sounds are made in tools/sounds).
--   One-shots: Sounds.play(name, options) plays a sound on your screen (2D); Sounds.at(name,
--   where, options) plays it in the world (3D) at a position, a part or an attachment;
--   Sounds.make(name, parent, looped) makes a Sound for a module to drive (the train's loop).
--   Sounds.ui(name) is a menu sound that also stands in for that click's generic click.
--   Every button in the player's ScreenGuis (not the dev panel, not Modal mouse-freeing buttons,
--   not ones with a Silent attribute) ticks on hover and clicks when pressed.
--   The round: the intro's 3-2-1 and GO, the last 10 s (a semitone higher each second, the
--   last 3 doubled), the whistle when the timer runs out, the buzzer when you're out, the lobby
--   countdown's last 5 s (the last beep held). Tags: the hitmarker for the tagger, the hit for
--   whoever is tagged, and in 3D for anyone near.
--   The background: near the lobby its rain and lo-fi music, near the loaded map its ambience
--   (Config.Sounds.MapAmbience) and its own music (MapMusic), or else the quiet round music;
--   loops placed on the map (a part's SoundLoop attribute) play in 3D; fades between them, silent on
--   the win screen, and left as it is anywhere else (the Locker's stage).
--   Victories: one track each (Sounds.victory(look) from client/Victories, stopVictory).
--   Three SoundGroups, Music, Sfx and Ui (the menu sounds, Config.Sounds.UiSounds, at UiGain),
--   follow the player's sliders and mute (the menu's Settings
--   page), kept in their profile's Settings through the SaveSettings remote.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Contestant = require(Shared:WaitForChild("Contestant"))
local GameState = require(Shared:WaitForChild("GameState"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Profile = require(script.Parent.Profile)

local Sounds = {}

export type Settings = { Music: number, Sfx: number, Ui: number, Muted: boolean }
export type Options = { volume: number?, speed: number? }

local C = Config.Sounds
local MUSIC = { [C.LobbyMusic] = true, [C.RoundMusic] = true }
for _, name in C.MapMusic do
	MUSIC[name] = true
end

local folder: Folder? = nil
local templates: { [string]: Sound } = {}
local groups: { Music: SoundGroup?, Sfx: SoundGroup?, Ui: SoundGroup? } =
	{ Music = nil, Sfx = nil, Ui = nil }
local settings: Settings = table.clone(C.Defaults) :: Settings
local editedAt = -math.huge -- when this client last changed the settings (the profile waits)
local settingsListeners: { (Settings) -> () } = {}
local specialAt = -math.huge
local hoverAt = -math.huge
local victoryTrack: Sound? = nil

local function group(name: string): SoundGroup?
	if MUSIC[name] then
		return groups.Music
	end
	return if C.UiSounds[name] then groups.Ui else groups.Sfx
end

-- The template for a sound (nil if it has no id).
local function template(name: string): Sound?
	local existing = templates[name]
	if existing then
		return existing
	end
	local entry = C.List[name]
	if not entry or entry.Id == 0 or not folder then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = "rbxassetid://" .. entry.Id
	sound.Volume = entry.Volume
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = C.MinDistance
	sound.RollOffMaxDistance = C.MaxDistance
	sound.SoundGroup = group(name)
	sound.Parent = folder
	templates[name] = sound
	return sound
end

local function fire(sound: Sound, options: Options?)
	if options then
		sound.Volume *= options.volume or 1
		sound.PlaybackSpeed = options.speed or 1
	end
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(sound.TimeLength > 0 and sound.TimeLength / sound.PlaybackSpeed + 1 or 30, function()
		if sound.Parent and not sound.IsPlaying then
			sound:Destroy()
		end
	end)
end

-- Plays a sound on your screen (2D).
function Sounds.play(name: string, options: Options?)
	local base = template(name)
	if base and folder then
		local sound = base:Clone()
		sound.Parent = folder
		fire(sound, options)
	end
end

-- Plays a sound in the world: at a position (a throwaway attachment), on a part or on an
-- attachment (it follows them).
function Sounds.at(name: string, where: Vector3 | Instance, options: Options?)
	local base = template(name)
	if not base then
		return
	end
	local sound = base:Clone()
	if typeof(where) == "Vector3" then
		local spot = Instance.new("Attachment")
		spot.WorldPosition = where
		spot.Parent = workspace.Terrain
		sound.Parent = spot
		sound.Ended:Once(function()
			spot:Destroy()
		end)
		task.delay(30, function()
			spot:Destroy()
		end)
	else
		sound.Parent = where
	end
	fire(sound, options)
end

-- A Sound in `parent` for a module to play and stop itself (nil if it has no id).
function Sounds.make(name: string, parent: Instance, looped: boolean?): Sound?
	local base = template(name)
	if not base then
		return nil
	end
	local sound = base:Clone()
	sound.Looped = looped == true
	sound.Parent = parent
	return sound
end

-- A menu sound (buy, equip, claim...): the press that caused it doesn't click as well.
function Sounds.ui(name: string)
	specialAt = os.clock()
	Sounds.play(name)
end

-- ---- Victories ---------------------------------------------------------------------------

function Sounds.stopVictory()
	local track = victoryTrack
	victoryTrack = nil
	if track then
		local fade = TweenService:Create(track, TweenInfo.new(0.4), { Volume = 0 })
		fade:Play()
		fade.Completed:Once(function()
			track:Destroy()
		end)
	end
end

-- Plays the track for a victory (its look.Victory), from the top.
function Sounds.victory(look: string?)
	Sounds.stopVictory()
	local name = look and C.Victories[look]
	local base = name and template(name)
	if base and folder then
		local track = base:Clone()
		track.Parent = folder
		track:Play()
		victoryTrack = track
	end
end

-- ---- Settings ----------------------------------------------------------------------------

local function applySettings()
	if groups.Music then
		groups.Music.Volume = if settings.Muted then 0 else settings.Music
	end
	if groups.Sfx then
		groups.Sfx.Volume = if settings.Muted then 0 else settings.Sfx
	end
	if groups.Ui then
		groups.Ui.Volume = if settings.Muted then 0 else settings.Ui * C.UiGain
	end
	for _, listener in settingsListeners do
		task.spawn(listener, settings)
	end
end

function Sounds.settings(): Settings
	return settings
end

function Sounds.onSettings(listener: (Settings) -> ())
	table.insert(settingsListeners, listener)
end

local saveQueued = false
-- Changes a setting ("Music", "Sfx" or "Ui" 0-1, "Muted"), applies it now and saves it shortly.
function Sounds.set(field: string, value: number | boolean)
	if field == "Music" or field == "Sfx" or field == "Ui" then
		(settings :: any)[field] = math.clamp(value :: number, 0, 1)
	elseif field == "Muted" then
		settings.Muted = value == true
	else
		return
	end
	editedAt = os.clock()
	applySettings()
	if not saveQueued then
		saveQueued = true
		task.delay(C.SaveDelay, function()
			saveQueued = false
			Remotes.get("SaveSettings"):FireServer(settings)
		end)
	end
end

-- ---- The background (ambience and music) -------------------------------------------------

local playing: { [string]: Sound } = {}

local function fadeTo(sound: Sound, volume: number, stopAfter: boolean)
	local tween = TweenService:Create(sound, TweenInfo.new(C.FadeTime), { Volume = volume })
	tween:Play()
	if stopAfter then
		tween.Completed:Once(function()
			if sound.Volume <= 0.001 then
				sound:Destroy()
			end
		end)
	end
end

local function setBackground(wanted: { [string]: boolean })
	for name, sound in playing do
		if not wanted[name] then
			playing[name] = nil
			fadeTo(sound, 0, true)
		end
	end
	for name in wanted do
		if not playing[name] and folder then
			local base = template(name)
			if base then
				local sound = base:Clone()
				sound.Looped = true
				sound.Volume = 0
				sound.Parent = folder
				sound:Play()
				playing[name] = sound
				fadeTo(sound, base.Volume, false)
			end
		end
	end
end

local function uploaded(name: string): boolean
	local entry = C.List[name]
	return entry ~= nil and entry.Id ~= 0
end

-- Looping sounds placed on the map: a part with a SoundLoop attribute (a sound's name) plays it
-- in 3D from there, heard from SoundNear studs at full volume out to SoundRange (the Space
-- Station's trench buzz).
local mapLoops: { Sound } = {}

local function addMapLoop(item: Instance)
	if not item:IsA("BasePart") then
		return
	end
	local name = item:GetAttribute("SoundLoop")
	if type(name) ~= "string" then
		return
	end
	local sound = Sounds.make(name, item, true)
	if not sound then
		return
	end
	local near, range = item:GetAttribute("SoundNear"), item:GetAttribute("SoundRange")
	if type(near) == "number" then
		sound.RollOffMinDistance = near
	end
	if type(range) == "number" then
		sound.RollOffMaxDistance = range
	end
	sound:Play()
	table.insert(mapLoops, sound)
end

local function watchMapLoops()
	local watching: RBXScriptConnection? = nil
	local function load(map: Instance)
		for _, sound in mapLoops do
			sound:Destroy()
		end
		table.clear(mapLoops)
		if watching then
			watching:Disconnect()
		end
		for _, item in map:GetDescendants() do
			addMapLoop(item)
		end
		watching = map.DescendantAdded:Connect(addMapLoop)
	end
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "ActiveMap" then
			load(child)
		end
	end)
	local current = workspace:FindFirstChild("ActiveMap")
	if current then
		load(current)
	end
end

-- What should be playing for where the camera is: nil keeps what's on.
local function wantedBackground(): { [string]: boolean }?
	if GameState.getPhase() == "Victory" then
		return {} -- the win screen: its victory only
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local focus = camera.Focus.Position
	local radius = Config.MapLighting.Radius
	local lobbyDistance = (focus - Config.Lobby.Position).Magnitude
	local map = workspace:FindFirstChild("ActiveMap")
	local mapDistance = if map and map:IsA("Model")
		then (focus - map:GetPivot().Position).Magnitude
		else math.huge
	if lobbyDistance <= mapDistance and lobbyDistance <= radius then
		return { [C.LobbyAmbience] = true, [C.LobbyMusic] = true }
	elseif map and mapDistance <= radius then
		-- The map's own ambience and music where it has them (and they're uploaded), else the
		-- quiet round music.
		local mapName = map:GetAttribute("MapName")
		local ambience = type(mapName) == "string" and C.MapAmbience[mapName]
		local music = type(mapName) == "string" and C.MapMusic[mapName]
		local wanted: { [string]: boolean } = {}
		if ambience and uploaded(ambience) then
			wanted[ambience] = true
		end
		if music and uploaded(music) then
			wanted[music] = true
		elseif not next(wanted) then
			wanted[C.RoundMusic] = true
		end
		return wanted
	end
	return nil
end

-- ---- The round ---------------------------------------------------------------------------

local function inRound(player: Player): boolean
	return player:GetAttribute("InGame") == true or player:GetAttribute("Spectating") == true
end

local function watchRound(player: Player)
	local lastPhase = GameState.getPhase()
	local lastTime = GameState.getTimeLeft()
	ReplicatedStorage:GetAttributeChangedSignal("TimeLeft"):Connect(function()
		local t = GameState.getTimeLeft()
		local phase = GameState.getPhase()
		if t > 0 then
			lastTime = t
		end
		if t < 1 then
			return
		end
		if phase == "Playing" and inRound(player) and t <= C.CountdownFrom then
			local speed = 2 ^ ((C.CountdownFrom - t) / 12)
			if t <= C.CountdownDoubled then
				Sounds.play("countdown", { speed = speed, volume = C.CountdownLoud })
				task.delay(C.CountdownDoubleGap, function()
					Sounds.play("countdown", { speed = speed, volume = C.CountdownLoud })
				end)
			else
				Sounds.play("countdown", { speed = speed })
			end
		elseif phase == "Intro" and inRound(player) and t <= C.IntroBeepFrom then
			Sounds.play("round_start_beep")
		elseif phase == "Countdown" and t <= C.LobbyBeepFrom then
			Sounds.play(if t == 1 then "lobby_beep_last" else "lobby_beep_beep")
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(function()
		local phase = GameState.getPhase()
		if lastPhase == "Intro" and phase == "Playing" and inRound(player) then
			Sounds.play("round_start_go")
		elseif
			lastPhase == "Playing"
			and phase == "Results"
			and lastTime <= 1
			and inRound(player)
		then
			Sounds.play("time_up") -- the timer ran out (not a round that ended early)
		end
		lastPhase = phase
	end)
	-- Out of the game: the buzzer.
	player:GetAttributeChangedSignal("Alive"):Connect(function()
		if
			player:GetAttribute("Alive") == false
			and player:GetAttribute("InGame") == true
			and player:GetAttribute("Spectating") ~= true
		then
			Sounds.play("eliminated")
		end
	end)
end

local function rootOf(who: Instance): BasePart?
	local character = Contestant.character(who :: any)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Another player's (or bot's) swing, at their body.
function Sounds.swingOf(swinger: Instance)
	local root = rootOf(swinger)
	if root then
		Sounds.at("swing", root, { volume = C.OthersVolume })
	end
end

local function watchTags(player: Player)
	Remotes.get("TagHit").OnClientEvent:Connect(function(tagger, tagged)
		if tagger == player then
			Sounds.play("tag_hit")
		elseif tagged == player then
			Sounds.play("tagged")
		elseif typeof(tagged) == "Instance" then
			local root = rootOf(tagged)
			if root then
				Sounds.at("tagged", root, { volume = C.OthersVolume })
			end
		end
	end)
end

-- ---- Buttons -----------------------------------------------------------------------------

local function wire(button: GuiButton)
	if button.Modal or button:GetAttribute("Silent") then
		return
	end
	button.MouseEnter:Connect(function()
		local now = os.clock()
		if now - hoverAt >= C.HoverGap and button.Active then
			hoverAt = now
			Sounds.play("ui_hover")
		end
	end)
	button.Activated:Connect(function()
		task.defer(function()
			if os.clock() - specialAt > 0.1 then
				Sounds.play("ui_click")
			end
		end)
	end)
end

local function watchGui(gui: Instance)
	if gui.Name == "DevPanel" then
		return
	end
	for _, item in gui:GetDescendants() do
		if item:IsA("GuiButton") then
			wire(item)
		end
	end
	gui.DescendantAdded:Connect(function(item)
		if item:IsA("GuiButton") then
			task.defer(wire, item) -- once its attributes are set
		end
	end)
end

function Sounds.start()
	local player = Players.LocalPlayer
	local root = Instance.new("Folder")
	root.Name = "GameSounds"
	root.Parent = SoundService
	folder = root
	local music = Instance.new("SoundGroup")
	music.Name = "Music"
	music.Parent = SoundService
	local sfx = Instance.new("SoundGroup")
	sfx.Name = "Sfx"
	sfx.Parent = SoundService
	local ui = Instance.new("SoundGroup")
	ui.Name = "Ui"
	ui.Parent = SoundService
	groups.Music, groups.Sfx, groups.Ui = music, sfx, ui
	applySettings()

	-- Load them all now so the first play isn't late.
	local all = {}
	for name in C.List do
		local sound = template(name)
		if sound then
			table.insert(all, sound)
		end
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(all)
		end)
	end)

	-- The saved settings (unless they were just changed here).
	Profile.onChanged(function(profile)
		local saved = profile and profile.Settings
		if type(saved) == "table" and os.clock() - editedAt > 5 then
			settings = {
				Music = math.clamp(tonumber(saved.Music) or C.Defaults.Music, 0, 1),
				Sfx = math.clamp(tonumber(saved.Sfx) or C.Defaults.Sfx, 0, 1),
				Ui = math.clamp(tonumber(saved.Ui) or C.Defaults.Ui, 0, 1),
				Muted = saved.Muted == true,
			}
			applySettings()
		end
	end)

	watchRound(player)
	watchTags(player)
	watchMapLoops()

	local playerGui = player:WaitForChild("PlayerGui")
	for _, gui in playerGui:GetChildren() do
		watchGui(gui)
	end
	playerGui.ChildAdded:Connect(watchGui)

	task.spawn(function()
		while true do
			local wanted = wantedBackground()
			if wanted then
				setBackground(wanted)
			end
			task.wait(0.5)
		end
	end)
end

return Sounds
