--!strict
-- The server side of the dev panel (client/DevPanel). Handles the DevCommand remote; every
-- request is checked with DevAccess first, so only developers can use it.
--   Game flow: SetMode, StartNow, Skip, SetTimeLeft, SetRoundTime, SetRole, Freeze, Unfreeze,
--              Respawn
--   Maps:      ListMaps (replies "Maps"), PlayMap, NextMap, UnloadMap
--   Movement:  SetTunable (only the values listed in Config.DevPanel.Tunables)
--   Progress:  GiveCoins, GiveXP, ResetProfile, AdvanceTime (moves the game calendar: DayClock),
--              ResetTime
-- Results and refusals are shown to the developer with the Notify remote.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local DevAccess = require(Shared.DevAccess)
local GameState = require(Shared.GameState)
local Remotes = require(Shared.Remotes)
local GameLoop = require(script.Parent.GameLoop)
local MapService = require(script.Parent.MapService)
local PlayerData = require(script.Parent.PlayerData)
local Progression = require(script.Parent.Progression)
local Roles = require(script.Parent.Roles)

local DevCommands = {}

local remote: RemoteEvent
local notify: RemoteEvent

local function tell(player: Player, text: string)
	notify:FireClient(player, text)
end

-- Phases where loading a map won't fight a running game.
local function canChangeMap(): boolean
	local phase = GameState.getPhase()
	return phase == "Lobby" or phase == "Countdown" or phase == "Sandbox"
end

local function sendMaps(player: Player)
	local active = MapService.active()
	local activeName = if active then active:GetAttribute("MapName") else nil
	remote:FireClient(player, "Maps", MapService.catalog(), activeName, MapService.getNext())
end

-- Puts these players' characters on the map's spawn points (or above its center if it has none).
local function placeOn(map: Model, players: { Player })
	local points = MapService.spawnPoints(map)
	for i, player in players do
		local character = player.Character
		if not character then
			continue
		end
		local point = points[((i - 1) % math.max(#points, 1)) + 1]
		local target = if point
			then point.CFrame + Vector3.new(0, 3, 0)
			else map:GetPivot() + Vector3.new(0, 10, 0)
		character:PivotTo(target)
	end
end

local function findTunable(section: string, key: string): { any }?
	for _, entry in Config.DevPanel.Tunables do
		if entry[1] == section and entry[2] == key then
			return entry
		end
	end
	return nil
end

local handlers: { [string]: (Player, ...any) -> () } = {}

handlers.SetMode = function(player, newMode)
	if newMode ~= "Elimination" and newMode ~= "Sandbox" then
		return
	end
	GameLoop.setMode(newMode)
	tell(player, `Mode: {newMode}`)
end

handlers.StartNow = function(player)
	local problem = GameLoop.startNow()
	tell(player, problem or "Starting the game")
end

handlers.Skip = function(player)
	tell(player, if GameLoop.skip() then `Skipped {GameState.getPhase()}` else "No timer to skip")
end

handlers.SetTimeLeft = function(player, seconds)
	if type(seconds) ~= "number" or seconds ~= seconds then
		return
	end
	tell(
		player,
		if GameLoop.setTimeLeft(seconds) then `Time left: {seconds}s` else "No timer running"
	)
end

handlers.SetRoundTime = function(player, seconds)
	if type(seconds) ~= "number" or seconds < 5 or seconds > 3600 then
		return
	end
	Config.Game.RoundTime = math.floor(seconds)
	tell(player, `Rounds now last {Config.Game.RoundTime}s (from the next round)`)
end

handlers.SetRole = function(player, role)
	if role ~= "It" and role ~= "Runner" and role ~= "None" then
		return
	end
	Roles.set(player, if role == "None" then nil else role)
	tell(player, `Role: {role}`)
end

handlers.Freeze = function(player, seconds)
	if type(seconds) ~= "number" or seconds <= 0 or seconds > 600 then
		return
	end
	Roles.freeze(player, seconds)
	tell(player, `Frozen for {seconds}s`)
end

handlers.Unfreeze = function(player)
	Roles.unfreeze(player)
	tell(player, "Unfrozen")
end

handlers.Respawn = function(player)
	player:LoadCharacter()
end

handlers.ListMaps = function(player)
	sendMaps(player)
end

handlers.PlayMap = function(player, name, everyone)
	if type(name) ~= "string" or not MapService.exists(name) then
		return
	end
	if not canChangeMap() then
		tell(player, "A game is running: use Next round instead")
		return
	end
	local map = MapService.load(name)
	placeOn(map, if everyone == true then Players:GetPlayers() else { player })
	tell(player, `Loaded {MapService.displayName(name)}`)
	sendMaps(player)
end

handlers.NextMap = function(player, name)
	if name ~= nil and (type(name) ~= "string" or not MapService.exists(name)) then
		return
	end
	MapService.setNext(name)
	tell(
		player,
		if name then `Next round: {MapService.displayName(name)}` else "Next round: automatic"
	)
	sendMaps(player)
end

handlers.UnloadMap = function(player)
	if not canChangeMap() then
		tell(player, "A game is running")
		return
	end
	MapService.unload()
	tell(player, "Map unloaded")
	sendMaps(player)
end

handlers.SetTunable = function(_player, section, key, value)
	if type(section) ~= "string" or type(key) ~= "string" or type(value) ~= "number" then
		return
	end
	local entry = findTunable(section, key)
	if not entry or value ~= value then
		return
	end
	local values = (Config :: any)[section]
	values[key] = math.clamp(value, entry[3], entry[4])
	if section == "Speed" then
		Roles.refreshAll()
	end
end

handlers.GiveCoins = function(player, amount)
	if type(amount) ~= "number" or amount ~= amount or math.abs(amount) > 1e7 then
		return
	end
	PlayerData.update(player, function(profile)
		profile.Coins = math.max(0, profile.Coins + math.floor(amount))
	end)
	tell(player, `Coins {if amount >= 0 then "+" else ""}{math.floor(amount)}`)
end

handlers.GiveXP = function(player, amount)
	if type(amount) ~= "number" or amount <= 0 or amount > 1e7 then
		return
	end
	Progression.grant(player, { XP = math.floor(amount) }, "Dev XP")
end

handlers.ResetProfile = function(player)
	PlayerData.reset(player)
	tell(player, "Profile reset")
end

-- Moves the game calendar forward (for testing streaks, daily quests and the shop rotation).
handlers.AdvanceTime = function(player, seconds)
	if type(seconds) ~= "number" or seconds <= 0 or seconds > 86400 * 60 then
		return
	end
	local offset = (ReplicatedStorage:GetAttribute("DevTimeOffset") or 0) :: number
	ReplicatedStorage:SetAttribute("DevTimeOffset", offset + seconds)
	tell(player, `Time +{seconds // 3600}h (offset {(offset + seconds) // 86400} days)`)
end

handlers.ResetTime = function(player)
	ReplicatedStorage:SetAttribute("DevTimeOffset", nil)
	tell(player, "Time back to real time")
end

function DevCommands.start()
	remote = Remotes.get("DevCommand")
	notify = Remotes.get("Notify")
	remote.OnServerEvent:Connect(function(player, command, ...)
		if not DevAccess.isDeveloper(player) or type(command) ~= "string" then
			return
		end
		local handler = handlers[command]
		if handler then
			handler(player, ...)
		end
	end)
end

return DevCommands
